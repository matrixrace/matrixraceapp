const { Router } = require('express');
const { globalRanking, leagueRanking, raceRanking } = require('../controllers/rankings.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Rotas autenticadas (rota específica ANTES da parametrizada)
router.get('/global', authenticate, globalRanking);
router.get('/league/:leagueId', authenticate, leagueRanking);
router.get('/league/:leagueId/race/:raceId', authenticate, raceRanking);

module.exports = router;
