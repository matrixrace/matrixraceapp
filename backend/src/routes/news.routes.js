const router = require('express').Router();
const { pool } = require('../config/database');
const { getNews, getNewsById } = require('../controllers/news.controller');

// Debug temporário — remover depois
router.get('/debug', async (req, res) => {
  try {
    const r1 = await pool.query('SELECT COUNT(*) as c FROM news');
    const r2 = await pool.query('SELECT id, is_published, substring(translations,1,80) as t FROM news LIMIT 3');
    const r3 = await pool.query('SELECT current_database(), version()');
    const dbUrl = process.env.DATABASE_URL || '';
    const hostMatch = dbUrl.match(/@([^/]+)/);
    res.json({ count: r1.rows[0], sample: r2.rows, db: r3.rows[0], dbHost: hostMatch ? hostMatch[1] : 'unknown' });
  } catch (e) {
    res.json({ error: e.message });
  }
});

// Trigger manual — remover depois
router.get('/fetch-now', async (req, res) => {
  try {
    const newsScheduler = require('../services/newsScheduler.service');
    await newsScheduler.fetchAndProcessNews();
    const r = await pool.query('SELECT COUNT(*) as c FROM news');
    res.json({ success: true, message: 'Fetch concluído', count: r.rows[0].c });
  } catch (e) {
    res.json({ success: false, error: e.message, stack: e.stack?.substring(0, 500) });
  }
});

// Rotas públicas (não requerem autenticação)
router.get('/', getNews);
router.get('/:id', getNewsById);

module.exports = router;
