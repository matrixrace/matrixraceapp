const router = require('express').Router();
const { pool } = require('../config/database');
const { getNews, getNewsById } = require('../controllers/news.controller');

// Debug temporário — remover depois
router.get('/debug', async (req, res) => {
  try {
    const r1 = await pool.query('SELECT COUNT(*) as c FROM news');
    const r2 = await pool.query('SELECT id, is_published, substring(translations,1,80) as t FROM news LIMIT 3');
    const r3 = await pool.query('SELECT current_database(), version()');
    // Mostra host do DB (sem senha)
    const dbUrl = process.env.DATABASE_URL || '';
    const hostMatch = dbUrl.match(/@([^/]+)/);
    res.json({ count: r1.rows[0], sample: r2.rows, db: r3.rows[0], dbHost: hostMatch ? hostMatch[1] : 'unknown' });
  } catch (e) {
    res.json({ error: e.message });
  }
});

// Rotas públicas (não requerem autenticação)
router.get('/', getNews);
router.get('/:id', getNewsById);

module.exports = router;
