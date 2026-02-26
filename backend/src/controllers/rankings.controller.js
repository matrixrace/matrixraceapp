const { getLeagueRanking, getRaceRanking } = require('../services/scoring.service');
const { successResponse } = require('../utils/helpers');

// GET /api/v1/rankings/league/:leagueId
// Ranking geral de uma liga (soma de todas as corridas)
async function leagueRanking(req, res, next) {
  try {
    const { leagueId } = req.params;
    const ranking = await getLeagueRanking(leagueId);
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

module.exports = { leagueRanking, raceRanking };
