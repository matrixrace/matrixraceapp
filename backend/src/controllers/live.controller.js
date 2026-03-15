const { db, pool } = require('../config/database');
const { races, drivers, raceResults, sessionResults, raceControlMessages } = require('../db/schema');
const { eq, and } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');
const { getIo } = require('../config/socket');
const { fetchSessionData } = require('../utils/openf1');
const { calculatePoints, calculateRaceScores } = require('../services/scoring.service');
const logger = require('../utils/logger');

const VALID_SESSION_TYPES = ['FP1', 'FP2', 'FP3', 'qualifying', 'sprint_qualifying', 'sprint', 'race'];

// ==================
// ADMIN: ATUALIZAR SESSAO VIA OPENF1
// ==================

// Logica pura de refresh (sem dependencia de req/res) — reutilizada pelo auto-refresh
async function doSessionRefresh(raceId, sessionType) {
  if (!VALID_SESSION_TYPES.includes(sessionType)) {
    throw new Error('Tipo de sessao invalido');
  }

  const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
  if (!race) throw new Error('Corrida nao encontrada');

  // Busca posicoes anteriores para comparacao (notificacoes)
  const previousResults = await pool.query(
    'SELECT driver_id, position FROM session_results WHERE race_id = $1 AND session_type = $2',
    [raceId, sessionType]
  );
  const prevPositions = {};
  for (const r of previousResults.rows) {
    prevPositions[r.driver_id] = r.position;
  }

  // Busca dados da OpenF1 API
  const apiData = await fetchSessionData(race.season, race.round, sessionType, race.country, race.name);

  // Busca mapeamento driver_code (abbreviation) -> driver_id do nosso banco
  const allDrivers = await db.select().from(drivers).where(eq(drivers.isActive, true));
  const driverByCode = {};
  const driverByNumber = {};
  for (const d of allDrivers) {
    if (d.abbreviation) driverByCode[d.abbreviation] = d.id;
    if (d.number) driverByNumber[d.number] = d.id;
  }

  // Remove resultados anteriores desta sessao
  await pool.query(
    'DELETE FROM session_results WHERE race_id = $1 AND session_type = $2',
    [raceId, sessionType]
  );

  // Insere novos resultados
  const insertedResults = [];
  for (const r of apiData.results) {
    // Tenta match por abbreviation primeiro, fallback para driver number
    const driverId = driverByCode[r.driverCode] || driverByNumber[r.driverNumber];
    if (!driverId) {
      logger.warn(`Piloto ${r.driverCode || r.driverNumber} nao encontrado no banco`);
      continue;
    }

    await pool.query(
      `INSERT INTO session_results (race_id, session_type, driver_id, position, best_lap_time, gap, tire_compound, pit_stops, status, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
      [raceId, sessionType, driverId, r.position, r.bestLapTime, r.gap, r.tireCompound, r.pitStops, r.status]
    );

    insertedResults.push({
      driverId,
      driverNumber: r.driverNumber,
      position: r.position,
      bestLapTime: r.bestLapTime,
      gap: r.gap,
      tireCompound: r.tireCompound,
      pitStops: r.pitStops,
      status: r.status,
    });
  }

  // Remove mensagens de controle anteriores e insere novas
  await pool.query(
    'DELETE FROM race_control_messages WHERE race_id = $1 AND session_type = $2',
    [raceId, sessionType]
  );

  for (const msg of apiData.raceControl) {
    await pool.query(
      `INSERT INTO race_control_messages (race_id, session_type, message, flag, driver_number, happened_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [raceId, sessionType, msg.message, msg.flag, msg.driverNumber, msg.happenedAt]
    );
  }

  // Emite atualizacao via socket
  const io = getIo();
  if (io) {
    io.to(`race:${raceId}`).emit('session_results_updated', {
      raceId,
      sessionType,
      results: insertedResults,
      raceControl: apiData.raceControl,
      updatedAt: new Date().toISOString(),
    });
  }

  // Gera notificacoes para pilotos que mudaram de posicao
  await generatePositionChangeNotifications(raceId, sessionType, insertedResults, prevPositions);

  logger.info(`Sessao ${sessionType} atualizada para corrida ${race.name}: ${insertedResults.length} pilotos`);
  return {
    results: insertedResults,
    raceControl: apiData.raceControl,
    count: insertedResults.length,
  };
}

// POST /api/v1/admin/races/:id/sessions/:sessionType/refresh
async function refreshSessionFromAPI(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const { sessionType } = req.params;
    const result = await doSessionRefresh(raceId, sessionType);
    res.json(successResponse(result, `Sessao ${sessionType} atualizada com sucesso`));
  } catch (error) {
    if (error.message.includes('Erro ao buscar') || error.message.includes('API') || error.message.includes('Nenhum')) {
      logger.error('OpenF1 API error:', error.message);
      return res.status(502).json({
        success: false,
        message: `Erro ao buscar dados da API: ${error.message}`,
        data: { manualFallback: true },
      });
    }
    next(error);
  }
}

// POST /api/v1/admin/races/:id/sessions/:sessionType/manual
async function manualSessionResults(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const { sessionType } = req.params;
    const { results } = req.body;

    if (!VALID_SESSION_TYPES.includes(sessionType)) {
      return next(errorResponse('Tipo de sessao invalido', 400));
    }

    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    // Remove resultados anteriores
    await pool.query(
      'DELETE FROM session_results WHERE race_id = $1 AND session_type = $2',
      [raceId, sessionType]
    );

    // Insere novos resultados
    const insertedResults = [];
    for (const r of results) {
      await pool.query(
        `INSERT INTO session_results (race_id, session_type, driver_id, position, best_lap_time, gap, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
        [raceId, sessionType, r.driverId, r.position, r.bestLapTime || null, r.gap || null]
      );
      insertedResults.push({ driverId: r.driverId, position: r.position, bestLapTime: r.bestLapTime || null, gap: r.gap || null });
    }

    // Emite atualizacao via socket
    const io = getIo();
    if (io) {
      io.to(`race:${raceId}`).emit('session_results_updated', {
        raceId,
        sessionType,
        results: insertedResults,
        raceControl: [],
        updatedAt: new Date().toISOString(),
      });
    }

    logger.info(`Sessao ${sessionType} atualizada manualmente para corrida ${race.name}`);
    res.json(successResponse({ results: insertedResults }, 'Resultados manuais salvos'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/admin/races/:id/finalize-results
async function finalizeRaceResults(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);

    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    // Busca resultados da sessao 'race'
    const sessionRes = await pool.query(
      'SELECT driver_id, position FROM session_results WHERE race_id = $1 AND session_type = $2 ORDER BY position',
      [raceId, 'race']
    );

    if (sessionRes.rows.length === 0) {
      return next(errorResponse('Nenhum resultado de corrida encontrado. Atualize a sessao "race" primeiro.', 400));
    }

    // Remove race_results anteriores
    await db.delete(raceResults).where(eq(raceResults.raceId, raceId));

    // Copia session_results -> race_results
    const values = sessionRes.rows.map((r) => ({
      raceId,
      driverId: r.driver_id,
      position: r.position,
    }));
    await db.insert(raceResults).values(values);

    // Marca corrida como completada
    await db.update(races).set({ isCompleted: true, updatedAt: new Date() }).where(eq(races.id, raceId));

    // Calcula pontuacoes oficiais
    const scoreResult = await calculateRaceScores(raceId);

    // Emite evento de finalizacao
    const io = getIo();
    if (io) {
      io.to(`race:${raceId}`).emit('race_finalized', { raceId });
    }

    logger.info(`Corrida ${race.name} finalizada e pontuacoes calculadas`);
    res.json(successResponse(scoreResult, 'Resultado oficial salvo e pontuacoes calculadas'));
  } catch (error) {
    next(error);
  }
}

// ==================
// PUBLICO: SESSOES E PONTUACAO PROVISORIA
// ==================

// GET /api/v1/races/:id/sessions
async function getSessionResults(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);

    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    // Busca todos os resultados de sessao
    const sessionsRes = await pool.query(
      `SELECT sr.session_type, sr.driver_id, sr.position, sr.best_lap_time, sr.gap,
              sr.tire_compound, sr.pit_stops, sr.status, sr.updated_at,
              d.first_name, d.last_name, d.abbreviation, d.number as driver_number,
              t.name as team_name, t.color_primary as team_color
       FROM session_results sr
       JOIN drivers d ON d.id = sr.driver_id
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE sr.race_id = $1
       ORDER BY sr.session_type, sr.position`,
      [raceId]
    );

    // Busca mensagens de controle
    const controlRes = await pool.query(
      `SELECT session_type, message, flag, driver_number, happened_at
       FROM race_control_messages
       WHERE race_id = $1
       ORDER BY happened_at DESC`,
      [raceId]
    );

    // Agrupa por session_type
    const sessions = {};
    for (const row of sessionsRes.rows) {
      const st = row.session_type;
      if (!sessions[st]) {
        sessions[st] = { sessionType: st, results: [], raceControl: [], updatedAt: null };
      }
      sessions[st].results.push({
        driverId: row.driver_id,
        driverNumber: row.driver_number,
        firstName: row.first_name,
        lastName: row.last_name,
        abbreviation: row.abbreviation,
        teamName: row.team_name,
        teamColor: row.team_color,
        position: row.position,
        bestLapTime: row.best_lap_time,
        gap: row.gap,
        tireCompound: row.tire_compound,
        pitStops: row.pit_stops,
        status: row.status,
      });
      if (row.updated_at) {
        const ts = new Date(row.updated_at).toISOString();
        if (!sessions[st].updatedAt || ts > sessions[st].updatedAt) {
          sessions[st].updatedAt = ts;
        }
      }
    }

    for (const msg of controlRes.rows) {
      const st = msg.session_type;
      if (sessions[st]) {
        sessions[st].raceControl.push({
          message: msg.message,
          flag: msg.flag,
          driverNumber: msg.driver_number,
          happenedAt: msg.happened_at,
        });
      }
    }

    // Determina sessoes disponiveis para o tipo de fim de semana
    const availableSessions = race.isSprintWeekend
      ? ['FP1', 'sprint_qualifying', 'sprint', 'qualifying', 'race']
      : ['FP1', 'FP2', 'FP3', 'qualifying', 'race'];

    res.json(successResponse({
      race: {
        id: race.id,
        name: race.name,
        location: race.location,
        country: race.country,
        isSprintWeekend: race.isSprintWeekend,
        isCompleted: race.isCompleted,
      },
      availableSessions,
      sessions,
    }));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/:id/live-scoring
async function getLiveScoring(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const userId = req.user.id;

    // Busca a ultima sessao atualizada
    const lastSession = await pool.query(
      `SELECT DISTINCT session_type, MAX(updated_at) as last_update
       FROM session_results WHERE race_id = $1
       GROUP BY session_type ORDER BY last_update DESC LIMIT 1`,
      [raceId]
    );

    if (lastSession.rows.length === 0) {
      return res.json(successResponse({
        sessionType: null,
        drivers: [],
        totalProvisionalPoints: 0,
      }));
    }

    const sessionType = lastSession.rows[0].session_type;

    // Busca posicoes atuais da sessao
    const positions = await pool.query(
      `SELECT sr.driver_id, sr.position, d.first_name, d.last_name, d.abbreviation,
              t.name as team_name, t.color_primary as team_color
       FROM session_results sr
       JOIN drivers d ON d.id = sr.driver_id
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE sr.race_id = $1 AND sr.session_type = $2
       ORDER BY sr.position`,
      [raceId, sessionType]
    );

    // Busca palpites do usuario para esta corrida
    const predictions = await pool.query(
      `SELECT driver_id, predicted_position, max_points_per_driver
       FROM predictions WHERE race_id = $1 AND user_id = $2`,
      [raceId, userId]
    );

    const predMap = {};
    for (const p of predictions.rows) {
      predMap[p.driver_id] = {
        predictedPosition: p.predicted_position,
        maxPoints: p.max_points_per_driver,
      };
    }

    // Calcula pontuacao provisoria
    let totalProvisionalPoints = 0;
    const driverScores = positions.rows.map((pos) => {
      const pred = predMap[pos.driver_id];
      let provisionalPoints = 0;
      let predictedPosition = null;

      if (pred) {
        predictedPosition = pred.predictedPosition;
        provisionalPoints = calculatePoints(pred.predictedPosition, pos.position, pred.maxPoints);
        totalProvisionalPoints += provisionalPoints;
      }

      return {
        driverId: pos.driver_id,
        firstName: pos.first_name,
        lastName: pos.last_name,
        abbreviation: pos.abbreviation,
        teamName: pos.team_name,
        teamColor: pos.team_color,
        currentPosition: pos.position,
        predictedPosition,
        provisionalPoints,
      };
    });

    res.json(successResponse({
      sessionType,
      updatedAt: lastSession.rows[0].last_update,
      drivers: driverScores,
      totalProvisionalPoints,
    }));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/:id/live-scoring/league/:leagueId
async function getLeagueLiveScoring(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const leagueId = req.params.leagueId;

    // Busca dados da corrida (para checar deadlines)
    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    const now = new Date();
    const isRaceFinalized = race.isCompleted === true;

    // Busca a ultima sessao atualizada
    const lastSession = await pool.query(
      `SELECT DISTINCT session_type, MAX(updated_at) as last_update
       FROM session_results WHERE race_id = $1
       GROUP BY session_type ORDER BY last_update DESC LIMIT 1`,
      [raceId]
    );

    const sessionType = lastSession.rows.length > 0 ? lastSession.rows[0].session_type : null;

    // Busca posicoes atuais (da ultima sessao)
    const actualPositions = {};
    if (sessionType) {
      const positionsRes = await pool.query(
        'SELECT driver_id, position FROM session_results WHERE race_id = $1 AND session_type = $2',
        [raceId, sessionType]
      );
      for (const r of positionsRes.rows) {
        actualPositions[r.driver_id] = r.position;
      }
    }

    // Busca TODOS os membros da liga (nao so quem aplicou)
    const allMembers = await pool.query(
      `SELECT lm.user_id, u.display_name, u.avatar_url, lm.joined_at
       FROM league_members lm
       JOIN users u ON u.id = lm.user_id
       WHERE lm.league_id = $1 AND lm.status = 'active' AND u.is_admin = false`,
      [leagueId]
    );

    // Verifica quem aplicou palpite nesta liga/corrida
    const applicants = await pool.query(
      `SELECT user_id FROM prediction_applications WHERE league_id = $1 AND race_id = $2`,
      [leagueId, raceId]
    );
    const appliedSet = new Set(applicants.rows.map(r => r.user_id));

    // Deadlines por lock_type
    const deadlines = {
      fp1: race.fp1Date ? new Date(race.fp1Date) : null,
      qualifying: race.qualifyingDate ? new Date(race.qualifyingDate) : null,
      race: race.raceDate ? new Date(race.raceDate) : null,
    };

    // Calcula pontuacao de cada membro
    const ranking = [];
    for (const member of allMembers.rows) {
      // Pontos oficiais de corridas anteriores nesta liga
      const officialScores = await pool.query(
        `SELECT COALESCE(SUM(points), 0) as total
         FROM scores WHERE league_id = $1 AND user_id = $2`,
        [leagueId, member.user_id]
      );
      const officialPoints = parseInt(officialScores.rows[0].total, 10);

      let provisionalPoints = 0;
      let lockType = null;
      let deadlinePassed = false;

      // So calcula provisorio se: aplicou palpite E ha posicoes de sessao
      if (appliedSet.has(member.user_id) && sessionType) {
        const preds = await pool.query(
          `SELECT driver_id, predicted_position, max_points_per_driver, lock_type
           FROM predictions WHERE race_id = $1 AND user_id = $2`,
          [raceId, member.user_id]
        );

        if (preds.rows.length > 0) {
          lockType = preds.rows[0].lock_type || 'race';
          const deadline = deadlines[lockType];
          deadlinePassed = deadline ? now >= deadline : false;

          // So mostra pontos se o deadline do user ja passou
          if (deadlinePassed) {
            for (const pred of preds.rows) {
              const actualPos = actualPositions[pred.driver_id];
              if (actualPos !== undefined) {
                provisionalPoints += calculatePoints(
                  pred.predicted_position, actualPos, pred.max_points_per_driver
                );
              }
            }
          }
        }
      }

      ranking.push({
        userId: member.user_id,
        displayName: member.display_name || 'Anonimo',
        avatarUrl: member.avatar_url,
        provisionalPoints,
        officialPoints,
        totalPoints: officialPoints + provisionalPoints,
        lockType,
        deadlinePassed,
        hasPrediction: appliedSet.has(member.user_id),
        joinedAt: member.joined_at,
      });
    }

    // Ordena por totalPoints desc, desempate por joined_at asc
    ranking.sort((a, b) => b.totalPoints - a.totalPoints || new Date(a.joinedAt) - new Date(b.joinedAt));
    ranking.forEach((r, i) => { r.position = i + 1; });

    res.json(successResponse({
      sessionType,
      updatedAt: lastSession.rows.length > 0 ? lastSession.rows[0].last_update : null,
      isFinalized: isRaceFinalized,
      ranking,
    }));
  } catch (error) {
    next(error);
  }
}

// ==================
// HELPER: NOTIFICACOES DE MUDANCA DE POSICAO
// ==================

async function generatePositionChangeNotifications(raceId, sessionType, newResults, prevPositions) {
  try {
    const io = getIo();

    for (const result of newResults) {
      const prevPos = prevPositions[result.driverId];
      if (prevPos === undefined || prevPos === result.position) continue;

      const direction = result.position < prevPos ? 'subiu' : 'caiu';
      const driverInfo = await pool.query(
        'SELECT first_name, last_name, abbreviation FROM drivers WHERE id = $1',
        [result.driverId]
      );
      if (driverInfo.rows.length === 0) continue;

      const driverName = `${driverInfo.rows[0].first_name} ${driverInfo.rows[0].last_name}`;
      const abbr = driverInfo.rows[0].abbreviation;

      // Busca usuarios que previram este piloto
      const usersWithPred = await pool.query(
        `SELECT user_id, predicted_position, max_points_per_driver
         FROM predictions WHERE race_id = $1 AND driver_id = $2`,
        [raceId, result.driverId]
      );

      for (const pred of usersWithPred.rows) {
        const pts = calculatePoints(pred.predicted_position, result.position, pred.max_points_per_driver);

        const title = `${abbr} ${direction} para P${result.position}!`;
        const body = `${driverName} ${direction} para P${result.position} no ${sessionType}. Sua pontuacao provisoria com ${abbr}: ${pts}pts`;

        // Insere notificacao no banco
        await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'live_position_change', $2, $3, $4)`,
          [pred.user_id, title, body, JSON.stringify({ raceId, sessionType, driverId: result.driverId, position: result.position })]
        );

        // Envia via socket se usuario estiver conectado
        if (io) {
          io.to(`user:${pred.user_id}`).emit('new_notification', {
            type: 'live_position_change',
            title,
            body,
            data: { raceId, sessionType, driverId: result.driverId, position: result.position },
          });
        }
      }
    }
  } catch (error) {
    logger.error('Erro ao gerar notificacoes de posicao:', error);
  }
}

// ==================
// EXTERNAL: IMPORTAR RESULTADOS VIA API KEY
// ==================

// POST /api/v1/live/external/races/:id/sessions/:sessionType/update
async function importSessionResults(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const { sessionType } = req.params;
    const { results } = req.body;

    if (!VALID_SESSION_TYPES.includes(sessionType)) {
      return next(errorResponse('Tipo de sessao invalido', 400));
    }

    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    // Busca todos os drivers ativos e cria mapa abbreviation -> id
    const allDrivers = await db.select().from(drivers).where(eq(drivers.isActive, true));
    const abbrevMap = {};
    for (const d of allDrivers) {
      if (d.abbreviation) abbrevMap[d.abbreviation.toUpperCase()] = d.id;
    }

    // Busca posicoes anteriores para notificacoes
    const previousResults = await pool.query(
      'SELECT driver_id, position FROM session_results WHERE race_id = $1 AND session_type = $2',
      [raceId, sessionType]
    );
    const prevPositions = {};
    for (const r of previousResults.rows) {
      prevPositions[r.driver_id] = r.position;
    }

    // Remove resultados anteriores
    await pool.query(
      'DELETE FROM session_results WHERE race_id = $1 AND session_type = $2',
      [raceId, sessionType]
    );

    // Insere novos resultados
    const insertedResults = [];
    const skipped = [];
    for (const r of results) {
      const abbr = r.abbreviation.toUpperCase();
      const driverId = abbrevMap[abbr];
      if (!driverId) {
        skipped.push(abbr);
        continue;
      }

      await pool.query(
        `INSERT INTO session_results (race_id, session_type, driver_id, position, best_lap_time, gap, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
        [raceId, sessionType, driverId, r.position, r.bestLapTime || null, r.gap || null]
      );

      insertedResults.push({
        driverId,
        abbreviation: abbr,
        position: r.position,
        bestLapTime: r.bestLapTime || null,
        gap: r.gap || null,
      });
    }

    // Emite atualizacao via socket
    const io = getIo();
    if (io) {
      io.to(`race:${raceId}`).emit('session_results_updated', {
        raceId,
        sessionType,
        results: insertedResults,
        raceControl: [],
        updatedAt: new Date().toISOString(),
      });
    }

    // Gera notificacoes de mudanca de posicao
    await generatePositionChangeNotifications(raceId, sessionType, insertedResults, prevPositions);

    logger.info(`Sessao ${sessionType} importada via API key para ${race.name}: ${insertedResults.length} pilotos`);
    res.json(successResponse({
      inserted: insertedResults.length,
      skipped,
      results: insertedResults,
    }, `Resultados importados: ${insertedResults.length} pilotos`));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/live/external/drivers
async function getExternalDrivers(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT d.id, d.abbreviation, d.first_name, d.last_name, d.number,
              t.name as team_name
       FROM drivers d
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE d.is_active = true
       ORDER BY d.abbreviation`
    );

    const driversList = result.rows.map(d => ({
      id: d.id,
      abbreviation: d.abbreviation,
      name: `${d.first_name} ${d.last_name}`,
      number: d.number,
      team: d.team_name,
    }));

    res.json(successResponse(driversList));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/live/external/races
async function getExternalRaces(req, res, next) {
  try {
    const season = parseInt(req.query.season) || new Date().getFullYear();
    const result = await pool.query(
      `SELECT id, name, round, season, race_date, is_sprint_weekend, is_completed
       FROM races WHERE season = $1 ORDER BY round`,
      [season]
    );

    const racesList = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      round: r.round,
      season: r.season,
      raceDate: r.race_date,
      isSprintWeekend: r.is_sprint_weekend,
      isCompleted: r.is_completed,
    }));

    res.json(successResponse(racesList));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/live/external/races/:id/finalize
async function externalFinalizeRace(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);

    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    const sessionRes = await pool.query(
      'SELECT driver_id, position FROM session_results WHERE race_id = $1 AND session_type = $2 ORDER BY position',
      [raceId, 'race']
    );

    if (sessionRes.rows.length === 0) {
      return res.status(400).json({ success: false, message: 'Nenhum resultado de corrida. Importe a sessao "race" primeiro.' });
    }

    await db.delete(raceResults).where(eq(raceResults.raceId, raceId));

    const values = sessionRes.rows.map((r) => ({ raceId, driverId: r.driver_id, position: r.position }));
    await db.insert(raceResults).values(values);

    await db.update(races).set({ isCompleted: true, updatedAt: new Date() }).where(eq(races.id, raceId));

    const scoreResult = await calculateRaceScores(raceId);

    const io = getIo();
    if (io) io.to(`race:${raceId}`).emit('race_finalized', { raceId });

    logger.info(`Corrida ${race.name} finalizada via API key`);
    res.json(successResponse(scoreResult, `Corrida ${race.name} finalizada! Pontuacoes calculadas.`));
  } catch (error) {
    next(error);
  }
}

// PATCH /api/v1/live/external/races/:id
async function externalUpdateRace(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const { isSprintWeekend, sprintQualifyingDate, sprintDate } = req.body;

    const updates = [];
    const values = [];
    let idx = 1;

    if (isSprintWeekend !== undefined) {
      updates.push(`is_sprint_weekend = $${idx++}`);
      values.push(Boolean(isSprintWeekend));
    }
    if (sprintQualifyingDate) {
      updates.push(`sprint_qualifying_date = $${idx++}`);
      values.push(new Date(sprintQualifyingDate));
    }
    if (sprintDate) {
      updates.push(`sprint_date = $${idx++}`);
      values.push(new Date(sprintDate));
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Nenhum campo para atualizar' });
    }

    updates.push(`updated_at = NOW()`);
    values.push(raceId);

    const result = await pool.query(
      `UPDATE races SET ${updates.join(', ')} WHERE id = $${idx} RETURNING id, name, is_sprint_weekend, sprint_qualifying_date, sprint_date`,
      values
    );

    if (result.rows.length === 0) {
      return next(errorResponse('Corrida nao encontrada', 404));
    }

    logger.info(`Corrida ${result.rows[0].name} atualizada: isSprintWeekend=${result.rows[0].is_sprint_weekend}`);
    res.json(successResponse(result.rows[0], 'Corrida atualizada'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/live/external/races/:id/refresh-all
// POST /api/v1/live/admin/races/:id/refresh-all-sessions
async function refreshAllSessions(req, res, next) {
  try {
    const raceId = parseInt(req.params.id);
    const [race] = await db.select().from(races).where(eq(races.id, raceId)).limit(1);
    if (!race) return next(errorResponse('Corrida nao encontrada', 404));

    const sessionTypes = race.isSprintWeekend
      ? ['FP1', 'sprint_qualifying', 'sprint', 'qualifying', 'race']
      : ['FP1', 'FP2', 'FP3', 'qualifying', 'race'];

    const refreshed = [];
    const failed = [];

    for (const st of sessionTypes) {
      try {
        const result = await doSessionRefresh(raceId, st);
        refreshed.push({ sessionType: st, count: result.count });
      } catch (err) {
        failed.push({ sessionType: st, error: err.message });
        logger.warn(`[RefreshAll] ${st} falhou: ${err.message}`);
      }
    }

    logger.info(`[RefreshAll] ${race.name}: ${refreshed.length} ok, ${failed.length} falhas`);
    res.json(successResponse(
      { refreshed, failed, raceName: race.name },
      `${refreshed.length} sessoes atualizadas, ${failed.length} falharam`
    ));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/live/external/migrate-abbreviations
// Migração única: atualiza abreviações dos drivers pelo nome
async function migrateAbbreviations(req, res, next) {
  try {
    const abbreviationMap = {
      'Franco Colapinto': 'COL',
      'Pierre Gasly': 'GAS',
      'Fernando Alonso': 'ALO',
      'Lance Stroll': 'STR',
      'Gabriel Bortoleto': 'BOR',
      'Nico Hülkenberg': 'HUL',
      'Nico Hulkenberg': 'HUL',
      'Valtteri Bottas': 'BOT',
      'Sergio Pérez': 'PER',
      'Sergio Perez': 'PER',
      'Lewis Hamilton': 'HAM',
      'Charles Leclerc': 'LEC',
      'Oliver Bearman': 'BEA',
      'Esteban Ocon': 'OCO',
      'Lando Norris': 'NOR',
      'Oscar Piastri': 'PIA',
      'Andrea Kimi Antonelli': 'ANT',
      'Kimi Antonelli': 'ANT',
      'George Russell': 'RUS',
      'Arvid Lindblad': 'LIN',
      'Liam Lawson': 'LAW',
      'Max Verstappen': 'VER',
      'Isack Hadjar': 'HAD',
      'Carlos Sainz': 'SAI',
      'Alexander Albon': 'ALB',
    };

    const driversRes = await pool.query('SELECT id, first_name, last_name, abbreviation FROM drivers');
    let updated = 0;
    const skipped = [];

    for (const d of driversRes.rows) {
      if (d.abbreviation) continue; // já tem abreviação
      const fullName = `${d.first_name} ${d.last_name}`;
      const abbr = abbreviationMap[fullName];
      if (abbr) {
        await pool.query('UPDATE drivers SET abbreviation = $1 WHERE id = $2', [abbr, d.id]);
        updated++;
      } else {
        skipped.push(fullName);
      }
    }

    res.json(successResponse({ updated, skipped }, `${updated} drivers atualizados`));
  } catch (error) {
    next(error);
  }
}

// ==================
// ADMIN: AUTO-REFRESH
// ==================

// POST /api/v1/live/admin/auto-refresh/start
async function startAutoRefresh(req, res, next) {
  try {
    const autoRefreshService = require('../services/autoRefresh.service');
    const { raceId, sessionType, intervalSeconds } = req.body;

    if (!raceId || !sessionType) {
      return next(errorResponse('raceId e sessionType sao obrigatorios', 400));
    }
    if (!VALID_SESSION_TYPES.includes(sessionType)) {
      return next(errorResponse('Tipo de sessao invalido', 400));
    }

    const intervalMs = (intervalSeconds || 30) * 1000;
    if (intervalMs < 10000) return next(errorResponse('Intervalo minimo: 10 segundos', 400));

    await autoRefreshService.start(parseInt(raceId), sessionType, intervalMs);

    logger.info(`Auto-refresh iniciado: raceId=${raceId} sessionType=${sessionType} interval=${intervalMs}ms`);
    res.json(successResponse(autoRefreshService.getStatus(), 'Auto-refresh iniciado'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/live/admin/auto-refresh/stop
async function stopAutoRefresh(req, res, next) {
  try {
    const autoRefreshService = require('../services/autoRefresh.service');
    await autoRefreshService.stop();

    logger.info('Auto-refresh parado');
    res.json(successResponse(autoRefreshService.getStatus(), 'Auto-refresh parado'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/live/admin/auto-refresh/status
async function getAutoRefreshStatus(req, res, next) {
  try {
    const autoRefreshService = require('../services/autoRefresh.service');
    res.json(successResponse(autoRefreshService.getStatus()));
  } catch (error) {
    next(error);
  }
}

module.exports = {
  doSessionRefresh,
  refreshSessionFromAPI,
  manualSessionResults,
  finalizeRaceResults,
  getSessionResults,
  getLiveScoring,
  getLeagueLiveScoring,
  importSessionResults,
  migrateAbbreviations,
  getExternalDrivers,
  getExternalRaces,
  externalFinalizeRace,
  refreshAllSessions,
  externalUpdateRace,
  startAutoRefresh,
  stopAutoRefresh,
  getAutoRefreshStatus,
};
