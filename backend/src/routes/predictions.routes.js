const { Router } = require('express');
const {
  createPrediction,
  applyPredictionToLeagues,
  getMyPredictionForRace,
  getRacePredictions,
  getMyPredictions,
  deletePrediction,
  getQuickOrder,
} = require('../controllers/predictions.controller');
const { authenticate, optionalAuth } = require('../middleware/auth');

const router = Router();

// Salvar/atualizar palpite para uma corrida
router.post('/', authenticate, createPrediction);

// Aplicar palpite em ligas
router.post('/apply', authenticate, applyPredictionToLeagues);

// Meus palpites por corrida específica
router.get('/race/:raceId', authenticate, getMyPredictionForRace);

// Meus palpites (resumo)
router.get('/me', authenticate, getMyPredictions);

// Sugestão de ordem rápida para o palpite (última corrida / campeonato / último palpite)
router.get('/quick-order', authenticate, getQuickOrder);

// Palpites de todos numa liga/corrida (só após a corrida começar)
router.get('/league/:leagueId/race/:raceId', optionalAuth, getRacePredictions);

// Apagar palpite de uma corrida (só se o prazo não esgotou)
router.delete('/race/:raceId', authenticate, deletePrediction);

module.exports = router;
