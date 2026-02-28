const router = require('express').Router();
const { getF1Results, getDriverStandings, getConstructorStandings } = require('../controllers/f1results.controller');

// GET /api/v1/f1-results?year=2025          → resultados de todas as corridas do ano
// GET /api/v1/f1-results/drivers?year=2025  → classificação de pilotos
// GET /api/v1/f1-results/constructors?year=2025 → classificação de construtores

router.get('/drivers', getDriverStandings);
router.get('/constructors', getConstructorStandings);
router.get('/', getF1Results);

module.exports = router;
