const { Router } = require('express');
const {
  getDashboardStats,
  getTeams, createTeam, updateTeam, deleteTeam, uploadTeamLogo,
  getDrivers, createDriver, updateDriver, deleteDriver, uploadDriverPhoto,
  getRaces, createRace, updateRace, deleteRace,
  createRaceResults, calculateScores,
  getOfficialLeagues, createOfficialLeague, updateOfficialLeague, deleteOfficialLeague, seedOfficialLeagues,
} = require('../controllers/admin.controller');
const { authenticate } = require('../middleware/auth');
const { requireAdmin } = require('../middleware/adminCheck');
const { validate } = require('../middleware/validator');
const { upload } = require('../middleware/upload');
const {
  createTeamSchema, updateTeamSchema,
  createDriverSchema, updateDriverSchema,
  createRaceSchema, updateRaceSchema,
  createRaceResultsSchema,
  createOfficialLeagueSchema, updateOfficialLeagueSchema,
} = require('../utils/validators');

const router = Router();

// Todas as rotas admin requerem autenticação + ser admin
router.use(authenticate, requireAdmin);

// Dashboard
router.get('/dashboard', getDashboardStats);

// Equipes
router.get('/teams', getTeams);
router.post('/teams', validate(createTeamSchema), createTeam);
router.put('/teams/:id', validate(updateTeamSchema), updateTeam);
router.delete('/teams/:id', deleteTeam);
router.post('/teams/:id/logo', upload.single('logo'), uploadTeamLogo);

// Pilotos
router.get('/drivers', getDrivers);
router.post('/drivers', validate(createDriverSchema), createDriver);
router.put('/drivers/:id', validate(updateDriverSchema), updateDriver);
router.delete('/drivers/:id', deleteDriver);
router.post('/drivers/:id/photo', upload.single('photo'), uploadDriverPhoto);

// Corridas
router.get('/races', getRaces);
router.post('/races', validate(createRaceSchema), createRace);
router.put('/races/:id', validate(updateRaceSchema), updateRace);
router.delete('/races/:id', deleteRace);

// Resultados
router.post('/races/:id/results', validate(createRaceResultsSchema), createRaceResults);
router.post('/races/:id/calculate-scores', calculateScores);

// Ligas Oficiais
router.get('/leagues', getOfficialLeagues);
router.post('/leagues/seed', seedOfficialLeagues);
router.post('/leagues', validate(createOfficialLeagueSchema), createOfficialLeague);
router.put('/leagues/:id', validate(updateOfficialLeagueSchema), updateOfficialLeague);
router.delete('/leagues/:id', deleteOfficialLeague);

module.exports = router;
