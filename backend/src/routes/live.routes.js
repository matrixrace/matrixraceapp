const { Router } = require('express');
const {
  refreshSessionFromAPI,
  manualSessionResults,
  finalizeRaceResults,
  getSessionResults,
  getLiveScoring,
  getLeagueLiveScoring,
} = require('../controllers/live.controller');
const { authenticate } = require('../middleware/auth');
const { requireAdmin } = require('../middleware/adminCheck');
const { validate } = require('../middleware/validator');
const { manualSessionResultsSchema } = require('../utils/validators');

const router = Router();

// Rotas publicas (autenticadas)
router.get('/races/:id/sessions', authenticate, getSessionResults);
router.get('/races/:id/live-scoring', authenticate, getLiveScoring);
router.get('/races/:id/live-scoring/league/:leagueId', authenticate, getLeagueLiveScoring);

// Rotas admin
router.post('/admin/races/:id/sessions/:sessionType/refresh', authenticate, requireAdmin, refreshSessionFromAPI);
router.post('/admin/races/:id/sessions/:sessionType/manual', authenticate, requireAdmin, validate(manualSessionResultsSchema), manualSessionResults);
router.post('/admin/races/:id/finalize-results', authenticate, requireAdmin, finalizeRaceResults);

module.exports = router;
