const { Router } = require('express');
const { leagueRanking, raceRanking } = require('../controllers/rankings.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Rotas autenticadas
router.get('/league/:leagueId', authenticate, leagueRanking);
router.get('/league/:leagueId/race/:raceId', authenticate, raceRanking);

module.exports = router;
