const { Router } = require('express');
const { getAllRaces, getUpcomingRaces, getRace, getActiveDrivers, getOfficialLeagueForRace } = require('../controllers/races.controller');

const router = Router();

// Rotas públicas (não precisa de login)
router.get('/all', getAllRaces);
router.get('/upcoming', getUpcomingRaces);
router.get('/drivers', getActiveDrivers);
router.get('/:id/official-league', getOfficialLeagueForRace);
router.get('/:id', getRace);

module.exports = router;
