const { db, pool } = require('../config/database');
const { predictions, predictionApplications, races, leagueMembers, leagueRaces } = require('../db/schema');
const { eq, and } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');
const logger = require('../utils/logger');

// Mapeia lock_type para max_points_per_driver
const LOCK_TYPE_POINTS = {
  fp1: 20,
  qualifying: 15,
  race: 10,
};

// Retorna se o palpite pode ser editado com base no lock_type e datas da corrida
function canEditPrediction(race, lockType) {
  const now = new Date();

  if (lockType === 'fp1') {
    // Só pode editar antes do FP1
    return race.fp1Date ? now < new Date(race.fp1Date) : true;
  }
  if (lockType === 'qualifying') {
    // Só pode editar antes da Classificação
    return race.qualifyingDate ? now < new Date(race.qualifyingDate) : true;
  }
  // lock_type = 'race': pode editar até o início da corrida
  return now < new Date(race.raceDate);
}

// POST /api/v1/predictions
// Cria ou atualiza o palpite do usuário para uma corrida (independente de liga)
async function createPrediction(req, res, next) {
  try {
    const raceId = req.body.raceId ?? req.body.race_id;
    const predictionList = req.body.predictions;
    const lockType = req.body.lockType ?? req.body.lock_type;
    const userId = req.user.id;

    // Valida lock_type
    const validLockTypes = ['fp1', 'qualifying', 'race'];
    const chosenLockType = lockType || 'race';
    if (!validLockTypes.includes(chosenLockType)) {
      return res.status(400).json(errorResponse('lock_type inválido. Use: fp1, qualifying ou race'));
    }

    // Busca a corrida
    const [race] = await db
      .select()
      .from(races)
      .where(eq(races.id, raceId))
      .limit(1);

    if (!race) {
      return res.status(404).json(errorResponse('Corrida não encontrada'));
    }

    if (race.isCompleted) {
      return res.status(400).json(errorResponse('Esta corrida já foi finalizada'));
    }

    // Verifica se a corrida ainda não começou (pelo menos antes da corrida)
    if (new Date() >= new Date(race.raceDate)) {
      return res.status(400).json(errorResponse('Esta corrida já começou. Palpites encerrados.'));
    }

    // Verifica se já existe um palpite travado que não pode ser alterado
    // (busca qualquer palpite existente para saber o lock_type atual)
    const existingResult = await pool.query(
      `SELECT DISTINCT lock_type FROM predictions WHERE race_id = $1 AND user_id = $2 LIMIT 1`,
      [raceId, userId]
    );

    if (existingResult.rows.length > 0) {
      const existingLockType = existingResult.rows[0].lock_type;
      // Verifica se o palpite atual está travado
      if (!canEditPrediction(race, existingLockType)) {
        return res.status(400).json(errorResponse(
          `Seu palpite foi travado (${existingLockType === 'fp1' ? 'antes do TL1' : existingLockType === 'qualifying' ? 'antes da Classificação' : 'antes da Corrida'}). Não é possível alterar.`
        ));
      }
    }

    const maxPoints = LOCK_TYPE_POINTS[chosenLockType];

    // Remove palpites anteriores do usuário para esta corrida
    await db
      .delete(predictions)
      .where(
        and(
          eq(predictions.raceId, raceId),
          eq(predictions.userId, userId)
        )
      );

    // Insere novos palpites com lock_type e max_points
    const values = predictionList.map((p) => ({
      raceId,
      userId,
      driverId: p.driver_id,
      predictedPosition: p.position,
      lockType: chosenLockType,
      maxPointsPerDriver: maxPoints,
    }));

    await db.insert(predictions).values(values);

    logger.info(`Palpite criado: ${req.user.email} - corrida ${race.name} (lock: ${chosenLockType}, max: ${maxPoints}pts)`);
    res.status(201).json(successResponse({ lockType: chosenLockType, maxPointsPerDriver: maxPoints }, 'Palpite salvo com sucesso!'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/predictions/apply
// Aplica o palpite do usuário em uma ou mais ligas
async function applyPredictionToLeagues(req, res, next) {
  try {
    const raceId = req.body.raceId ?? req.body.race_id;
    const leagueIds = req.body.leagueIds ?? req.body.league_ids;
    const userId = req.user.id;

    if (!leagueIds || !Array.isArray(leagueIds) || leagueIds.length === 0) {
      return res.status(400).json(errorResponse('Informe pelo menos uma liga'));
    }

    // Verifica se o usuário tem palpite para esta corrida
    const existingResult = await pool.query(
      `SELECT DISTINCT lock_type FROM predictions WHERE race_id = $1 AND user_id = $2 LIMIT 1`,
      [raceId, userId]
    );

    if (existingResult.rows.length === 0) {
      return res.status(400).json(errorResponse('Você ainda não fez um palpite para esta corrida'));
    }

    // Remove aplicações anteriores para esta corrida/usuário antes de reaplicar
    await pool.query(
      `DELETE FROM prediction_applications WHERE race_id = $1 AND user_id = $2`,
      [raceId, userId]
    );

    const applied = [];
    const errors = [];

    for (const leagueId of leagueIds) {
      // Busca informações da liga
      const leagueInfo = await pool.query(
        `SELECT id, is_official, is_public, requires_approval FROM leagues WHERE id = $1`,
        [leagueId]
      );

      if (leagueInfo.rows.length === 0) {
        errors.push(`Liga não encontrada`);
        continue;
      }

      const league = leagueInfo.rows[0];

      // Verifica se o usuário é membro ativo da liga
      const memberCheck = await pool.query(
        `SELECT 1 FROM league_members WHERE league_id = $1 AND user_id = $2 AND status = 'active'`,
        [leagueId, userId]
      );

      if (memberCheck.rowCount === 0) {
        // Auto-join: ligas oficiais OU ligas públicas sem aprovação
        if (league.is_public && !league.requires_approval) {
          await pool.query(
            `INSERT INTO league_members (league_id, user_id, status) VALUES ($1, $2, 'active') ON CONFLICT DO NOTHING`,
            [leagueId, userId]
          );
        } else {
          errors.push(`Você não é membro de uma das ligas informadas`);
          continue;
        }
      }

      // Verifica se a corrida faz parte da liga
      const [lr] = await db
        .select()
        .from(leagueRaces)
        .where(and(eq(leagueRaces.leagueId, leagueId), eq(leagueRaces.raceId, raceId)))
        .limit(1);

      if (!lr) {
        errors.push(`Esta corrida não faz parte de uma das ligas`);
        continue;
      }

      // Aplica o palpite na liga (upsert)
      await pool.query(
        `INSERT INTO prediction_applications (league_id, race_id, user_id)
         VALUES ($1, $2, $3)
         ON CONFLICT (league_id, race_id, user_id) DO UPDATE SET applied_at = NOW()`,
        [leagueId, raceId, userId]
      );

      applied.push(leagueId);
    }

    logger.info(`Palpite aplicado em ${applied.length} liga(s): ${req.user.email} - corrida ${raceId}`);
    res.status(201).json(successResponse(
      { applied: applied.length, errors },
      `Palpite aplicado em ${applied.length} liga(s)!`
    ));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/predictions/race/:raceId
// Retorna o palpite do usuário logado para uma corrida
async function getMyPredictionForRace(req, res, next) {
  try {
    const { raceId } = req.params;
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT p.predicted_position, p.lock_type, p.max_points_per_driver,
              d.id as driver_id, d.first_name, d.last_name, d.number, d.photo_url,
              t.name as team_name, t.color_primary as team_color
       FROM predictions p
       JOIN drivers d ON d.id = p.driver_id
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE p.race_id = $1 AND p.user_id = $2
       ORDER BY p.predicted_position`,
      [raceId, userId]
    );

    // Busca ligas onde o palpite está aplicado
    const appsResult = await pool.query(
      `SELECT pa.league_id, l.name as league_name
       FROM prediction_applications pa
       JOIN leagues l ON l.id = pa.league_id
       WHERE pa.race_id = $1 AND pa.user_id = $2`,
      [raceId, userId]
    );

    res.json(successResponse({
      predictions: result.rows,
      appliedLeagues: appsResult.rows,
      lockType: result.rows[0]?.lock_type || null,
      maxPoints: result.rows[0]?.max_points_per_driver || null,
    }));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/predictions/league/:leagueId/race/:raceId
// Ver palpites de todos os membros (só após a corrida começar)
async function getRacePredictions(req, res, next) {
  try {
    const { leagueId, raceId } = req.params;

    const [race] = await db
      .select()
      .from(races)
      .where(eq(races.id, parseInt(raceId)))
      .limit(1);

    if (!race) {
      return res.status(404).json(errorResponse('Corrida não encontrada'));
    }

    const raceStarted = new Date() >= new Date(race.raceDate);

    if (!raceStarted && !race.isCompleted) {
      // Antes da corrida: só mostra o palpite do próprio usuário
      if (!req.user) {
        return res.json(successResponse([], 'Palpites serão revelados quando a corrida começar'));
      }
      const result = await pool.query(
        `SELECT p.predicted_position, p.lock_type, p.max_points_per_driver,
                d.first_name, d.last_name, d.number,
                t.name as team_name, t.color_primary as team_color
         FROM predictions p
         JOIN prediction_applications pa ON pa.race_id = p.race_id AND pa.user_id = p.user_id
         JOIN drivers d ON d.id = p.driver_id
         LEFT JOIN teams t ON t.id = d.team_id
         WHERE p.race_id = $1 AND p.user_id = $2 AND pa.league_id = $3
         ORDER BY p.predicted_position`,
        [raceId, req.user.id, leagueId]
      );
      return res.json(successResponse(result.rows));
    }

    // Após a corrida começar: mostra todos os palpites aplicados na liga
    const result = await pool.query(
      `SELECT p.predicted_position, p.lock_type, p.max_points_per_driver,
              u.display_name, u.avatar_url,
              d.first_name, d.last_name, d.number,
              t.name as team_name, t.color_primary as team_color
       FROM predictions p
       JOIN prediction_applications pa ON pa.race_id = p.race_id AND pa.user_id = p.user_id AND pa.league_id = $1
       JOIN users u ON u.id = p.user_id
       JOIN drivers d ON d.id = p.driver_id
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE p.race_id = $2
       ORDER BY u.display_name, p.predicted_position`,
      [leagueId, raceId]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/predictions/me
async function getMyPredictions(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT DISTINCT ON (p.race_id)
              p.race_id, p.lock_type, p.max_points_per_driver, p.updated_at,
              r.name as race_name, r.race_date, r.fp1_date, r.qualifying_date, r.round
       FROM predictions p
       JOIN races r ON r.id = p.race_id
       WHERE p.user_id = $1
       ORDER BY p.race_id, r.race_date DESC`,
      [req.user.id]
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// DELETE /api/v1/predictions/race/:raceId
// Apaga o palpite do usuário para uma corrida (só se o prazo não esgotou)
async function deletePrediction(req, res, next) {
  try {
    const raceId = parseInt(req.params.raceId);
    const userId = req.user.id;

    // Busca o palpite existente e dados da corrida
    const result = await pool.query(
      `SELECT p.lock_type, r.fp1_date, r.qualifying_date, r.race_date
       FROM predictions p
       JOIN races r ON r.id = p.race_id
       WHERE p.race_id = $1 AND p.user_id = $2
       LIMIT 1`,
      [raceId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json(errorResponse('Palpite não encontrado'));
    }

    const { lock_type, fp1_date, qualifying_date, race_date } = result.rows[0];
    const race = { fp1Date: fp1_date, qualifyingDate: qualifying_date, raceDate: race_date };

    if (!canEditPrediction(race, lock_type)) {
      return res.status(403).json(errorResponse('Prazo esgotado — palpite não pode mais ser apagado'));
    }

    // Remove aplicações em ligas e o palpite
    await db.delete(predictionApplications).where(
      and(eq(predictionApplications.raceId, raceId), eq(predictionApplications.userId, userId))
    );
    await db.delete(predictions).where(
      and(eq(predictions.raceId, raceId), eq(predictions.userId, userId))
    );

    res.json(successResponse(null, 'Palpite apagado com sucesso'));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  createPrediction,
  applyPredictionToLeagues,
  getMyPredictionForRace,
  getRacePredictions,
  getMyPredictions,
  deletePrediction,
};
