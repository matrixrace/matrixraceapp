const { getGlobalRanking, getLeagueRanking, getPodiumStats, getRaceRanking } = require('../services/scoring.service');
const { successResponse } = require('../utils/helpers');

// GET /api/v1/rankings/global
// Ranking global por GP (deduplicado entre ligas)
async function globalRanking(req, res, next) {
  try {
    const { month, preset, startDate, endDate } = req.query;
    const ranking = await getGlobalRanking({ month, preset, startDate, endDate });

    // Enriquece com podiumStats
    const userIds = ranking.map(r => r.userId);
    const podium = await getPodiumStats(userIds);
    for (const entry of ranking) {
      entry.podiumStats = podium[entry.userId] || { gold: 0, silver: 0, bronze: 0 };
    }

    res.json(successResponse(ranking));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/rankings/league/:leagueId
// Ranking geral de uma liga (soma de todas as corridas)
async function leagueRanking(req, res, next) {
  try {
    const { leagueId } = req.params;
    const ranking = await getLeagueRanking(leagueId);

    // Enriquece com podiumStats
    const userIds = ranking.map(r => r.userId);
    const podium = await getPodiumStats(userIds);
    for (const entry of ranking) {
      entry.podiumStats = podium[entry.userId] || { gold: 0, silver: 0, bronze: 0 };
    }

    res.json(successResponse(ranking));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/rankings/league/:leagueId/race/:raceId
// Ranking de uma corrida específica dentro de uma liga
async function raceRanking(req, res, next) {
  try {
    const { leagueId, raceId } = req.params;
    const ranking = await getRaceRanking(leagueId, parseInt(raceId));
    res.json(successResponse(ranking));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/rankings/podium-stats
// Estatísticas de pódio em lote para uma lista de usuários
async function podiumStats(req, res, next) {
  try {
    const { userIds } = req.body;
    const stats = await getPodiumStats(userIds);
    res.json(successResponse(stats));
  } catch (error) {
    next(error);
  }
}

module.exports = { globalRanking, leagueRanking, podiumStats, raceRanking };
