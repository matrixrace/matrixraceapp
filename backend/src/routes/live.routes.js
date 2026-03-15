const { Router } = require('express');
const {
  refreshSessionFromAPI,
  manualSessionResults,
  finalizeRaceResults,
  getSessionResults,
  getLiveScoring,
  getLeagueLiveScoring,
  importSessionResults,
  getExternalDrivers,
  getExternalRaces,
  migrateAbbreviations,
  externalFinalizeRace,
  refreshAllSessions,
  externalUpdateRace,
  startAutoRefresh,
  stopAutoRefresh,
  getAutoRefreshStatus,
} = require('../controllers/live.controller');
const { authenticate } = require('../middleware/auth');
const { requireAdmin } = require('../middleware/adminCheck');
const { authenticateApiKey } = require('../middleware/apiKeyAuth');
const { validate } = require('../middleware/validator');
const { manualSessionResultsSchema, importSessionResultsSchema } = require('../utils/validators');

const router = Router();

// Rotas externas (API key) - ANTES das rotas parametrizadas
router.get('/external/drivers', authenticateApiKey, getExternalDrivers);
router.get('/external/races', authenticateApiKey, getExternalRaces);
router.post('/external/races/:id/sessions/:sessionType/update', authenticateApiKey, validate(importSessionResultsSchema), importSessionResults);
router.post('/external/migrate-abbreviations', authenticateApiKey, migrateAbbreviations);
router.post('/external/races/:id/finalize', authenticateApiKey, externalFinalizeRace);
router.post('/external/races/:id/refresh-all', authenticateApiKey, refreshAllSessions);
router.patch('/external/races/:id', authenticateApiKey, externalUpdateRace);

// Rotas publicas (autenticadas)
router.get('/races/:id/sessions', authenticate, getSessionResults);
router.get('/races/:id/live-scoring', authenticate, getLiveScoring);
router.get('/races/:id/live-scoring/league/:leagueId', authenticate, getLeagueLiveScoring);

// Rotas admin
router.post('/admin/auto-refresh/start', authenticate, requireAdmin, startAutoRefresh);
router.post('/admin/auto-refresh/stop', authenticate, requireAdmin, stopAutoRefresh);
router.get('/admin/auto-refresh/status', authenticate, requireAdmin, getAutoRefreshStatus);
router.get('/admin/scheduler/diagnostics', authenticate, requireAdmin, (req, res) => {
  const sessionScheduler = require('../services/sessionScheduler.service');
  res.json({ success: true, data: sessionScheduler.getDiagnostics() });
});
router.post('/admin/races/:id/sessions/:sessionType/refresh', authenticate, requireAdmin, refreshSessionFromAPI);
router.post('/admin/races/:id/sessions/:sessionType/manual', authenticate, requireAdmin, validate(manualSessionResultsSchema), manualSessionResults);
router.post('/admin/races/:id/finalize-results', authenticate, requireAdmin, finalizeRaceResults);
router.post('/admin/races/:id/refresh-all-sessions', authenticate, requireAdmin, refreshAllSessions);

module.exports = router;
