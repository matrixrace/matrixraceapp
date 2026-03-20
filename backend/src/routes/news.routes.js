const router = require('express').Router();
const { pool } = require('../config/database');
const { getNews, getNewsById } = require('../controllers/news.controller');

// Status do scheduler (diagnóstico)
router.get('/status', (req, res) => {
  const newsScheduler = require('../services/newsScheduler.service');
  res.json({ success: true, data: newsScheduler.getDiagnostics() });
});

// Trigger manual de busca com diagnóstico detalhado
router.get('/fetch-now', async (req, res) => {
  try {
    const newsScheduler = require('../services/newsScheduler.service');
    const result = await newsScheduler.fetchAndProcessNews({ returnDiag: true });
    const countRes = await pool.query('SELECT COUNT(*)::int as count FROM news WHERE is_published = true');
    res.json({
      success: true,
      message: `Fetch concluído: ${result?.inserted || 0} inseridas`,
      count: countRes.rows[0]?.count || 0,
      diag: result,
    });
  } catch (e) {
    res.json({ success: false, error: e.message, stack: e.stack?.substring(0, 500) });
  }
});

// Rotas públicas (não requerem autenticação)
router.get('/', getNews);
router.get('/:id', getNewsById);

module.exports = router;
