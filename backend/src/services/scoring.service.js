const { db, pool } = require('../config/database');
const { scores, leagueRaces, leagueMembers } = require('../db/schema');
const { eq, and } = require('drizzle-orm');
const logger = require('../utils/logger');

// Calcula pontos de UM palpite
// max_points depende de quando o usuário travou o palpite:
//   fp1       -> max 20 pts por piloto acertado
//   qualifying -> max 15 pts por piloto acertado
//   race      -> max 10 pts por piloto acertado
// Fórmula: max(0, maxPoints - abs(previsto - real))
function calculatePoints(predictedPosition, actualPosition, maxPoints = 10) {
  const difference = Math.abs(predictedPosition - actualPosition);
  return Math.max(0, maxPoints - difference);
}

// Calcula todas as pontuações de uma corrida para todas as ligas
// Usa apenas palpites que foram APLICADOS em cada liga (prediction_applications)
async function calculateRaceScores(raceId) {
  logger.info(`Calculando pontuações para corrida ${raceId}`);

  // 1. Busca os resultados reais da corrida
  const results = await pool.query(
    `SELECT driver_id, position FROM race_results WHERE race_id = $1`,
    [raceId]
  );

  if (results.rows.length === 0) {
    throw new Error('Nenhum resultado cadastrado para esta corrida');
  }

  // Monta mapa: driverId -> posição real
  const actualPositions = {};
  for (const result of results.rows) {
    actualPositions[result.driver_id] = result.position;
  }

  // 2. Busca todas as ligas que incluem esta corrida
  const leaguesWithRace = await pool.query(
    `SELECT DISTINCT league_id FROM league_races WHERE race_id = $1`,
    [raceId]
  );

  let totalUsersProcessed = 0;
  let totalLeaguesProcessed = 0;

  // 3. Para cada liga, calcula pontos de cada membro que aplicou o palpite
  for (const lr of leaguesWithRace.rows) {
    const leagueId = lr.league_id;

    // Busca usuários que aplicaram palpite nesta liga/corrida
    const applicants = await pool.query(
      `SELECT DISTINCT user_id FROM prediction_applications
       WHERE league_id = $1 AND race_id = $2`,
      [leagueId, raceId]
    );

    for (const applicant of applicants.rows) {
      const userId = applicant.user_id;

      // Busca os palpites do usuário para esta corrida
      const userPredictions = await pool.query(
        `SELECT driver_id, predicted_position, max_points_per_driver
         FROM predictions
         WHERE race_id = $1 AND user_id = $2`,
        [raceId, userId]
      );

      // Calcula pontos totais usando o max_points_per_driver de cada palpite
      let totalPoints = 0;
      for (const pred of userPredictions.rows) {
        const actualPos = actualPositions[pred.driver_id];
        if (actualPos !== undefined) {
          totalPoints += calculatePoints(
            pred.predicted_position,
            actualPos,
            pred.max_points_per_driver
          );
        }
      }

      // Salva ou atualiza a pontuação
      await pool.query(
        `INSERT INTO scores (league_id, race_id, user_id, points, calculated_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (league_id, race_id, user_id) DO UPDATE
         SET points = $4, calculated_at = NOW()`,
        [leagueId, raceId, userId, totalPoints]
      );

      totalUsersProcessed++;
    }

    totalLeaguesProcessed++;
  }

  logger.info(
    `Pontuações calculadas: ${totalUsersProcessed} usuários em ${totalLeaguesProcessed} ligas`
  );

  return {
    racesProcessed: 1,
    leaguesProcessed: totalLeaguesProcessed,
    usersProcessed: totalUsersProcessed,
  };
}

// Ranking geral de uma liga (soma de todas as corridas)
async function getLeagueRanking(leagueId) {
  const result = await pool.query(
    `SELECT
      u.id,
      u.display_name,
      u.avatar_url,
      COALESCE(SUM(s.points), 0) as total_points,
      COUNT(DISTINCT s.race_id) as races_played
    FROM league_members lm
    JOIN users u ON u.id = lm.user_id
    LEFT JOIN scores s ON s.user_id = lm.user_id AND s.league_id = lm.league_id
    WHERE lm.league_id = $1
    GROUP BY u.id, u.display_name, u.avatar_url
    ORDER BY total_points DESC`,
    [leagueId]
  );

  return result.rows.map((row, index) => ({
    position: index + 1,
    userId: row.id,
    displayName: row.display_name || 'Anônimo',
    avatarUrl: row.avatar_url,
    totalPoints: parseInt(row.total_points, 10),
    racesPlayed: parseInt(row.races_played, 10),
  }));
}

// Ranking de uma corrida específica dentro de uma liga
async function getRaceRanking(leagueId, raceId) {
  const result = await pool.query(
    `SELECT
      u.id,
      u.display_name,
      u.avatar_url,
      COALESCE(s.points, 0) as points,
      p_meta.lock_type,
      p_meta.max_points_per_driver
    FROM league_members lm
    JOIN users u ON u.id = lm.user_id
    LEFT JOIN scores s ON s.user_id = lm.user_id
      AND s.league_id = lm.league_id
      AND s.race_id = $2
    LEFT JOIN LATERAL (
      SELECT DISTINCT lock_type, max_points_per_driver
      FROM predictions
      WHERE user_id = lm.user_id AND race_id = $2
      LIMIT 1
    ) p_meta ON true
    WHERE lm.league_id = $1
    ORDER BY points DESC`,
    [leagueId, raceId]
  );

  return result.rows.map((row, index) => ({
    position: index + 1,
    userId: row.id,
    displayName: row.display_name || 'Anônimo',
    avatarUrl: row.avatar_url,
    points: parseInt(row.points, 10),
    lockType: row.lock_type,
    maxPointsPerDriver: row.max_points_per_driver,
  }));
}

module.exports = {
  calculatePoints,
  calculateRaceScores,
  getLeagueRanking,
  getRaceRanking,
};
