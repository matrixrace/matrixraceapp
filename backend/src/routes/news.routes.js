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

// Trigger manual com diagnóstico — remover depois
router.get('/fetch-now', async (req, res) => {
  const diag = { steps: [] };
  try {
    const { fetchAllFeeds } = require('../utils/rss');
    const { callMiniMaxJSON } = require('../utils/minimax');
    const crypto = require('crypto');

    // Step 1: RSS
    diag.steps.push('1-rss-start');
    let articles;
    try {
      articles = await fetchAllFeeds(5);
      diag.rssCount = articles.length;
      diag.rssSample = articles.slice(0, 3).map(a => ({ title: a.title?.substring(0, 80), source: a.sourceName }));
      diag.steps.push('1-rss-ok');
    } catch (e) {
      diag.rssError = e.message;
      diag.steps.push('1-rss-fail');
      return res.json({ success: false, diag });
    }

    if (articles.length === 0) {
      diag.steps.push('1-rss-empty');
      const r = await pool.query('SELECT COUNT(*) as c FROM news');
      return res.json({ success: true, message: 'Nenhum artigo nos feeds', count: r.rows[0].c, diag });
    }

    // Step 2: Dedup
    diag.steps.push('2-dedup-start');
    let newArticles;
    try {
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const hashResult = await pool.query('SELECT title_hash FROM news WHERE published_at >= $1', [sevenDaysAgo]);
      const existingHashes = new Set(hashResult.rows.map(r => r.title_hash));
      diag.existingHashCount = existingHashes.size;

      function computeTitleHash(title) {
        const normalized = title.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
        return crypto.createHash('sha256').update(normalized).digest('hex');
      }

      newArticles = articles.filter(a => !existingHashes.has(computeTitleHash(a.title)));
      diag.afterDedupCount = newArticles.length;
      diag.steps.push('2-dedup-ok');
    } catch (e) {
      diag.dedupError = e.message;
      diag.steps.push('2-dedup-fail');
      return res.json({ success: false, diag });
    }

    if (newArticles.length === 0) {
      diag.steps.push('2-dedup-all-known');
      const r = await pool.query('SELECT COUNT(*) as c FROM news');
      return res.json({ success: true, message: 'Todos artigos já conhecidos', count: r.rows[0].c, diag });
    }

    // Step 3: MiniMax
    diag.steps.push('3-minimax-start');
    const batch = newArticles.slice(0, 50);
    const userMessage = JSON.stringify(batch.map(a => ({
      title: a.title, description: a.description?.substring(0, 300) || '', source: a.sourceName, url: a.link, date: a.pubDate?.toISOString(),
    })));
    diag.minimaxInputArticles = batch.length;

    let result;
    try {
      result = await callMiniMaxJSON(
        'Você é um editor de notícias de F1. Analise os artigos e retorne JSON com { "articles": [...] }. Cada artigo: title_pt, summary_pt, title_en, summary_en, category, original_titles, source_names, source_urls, image_url. Max 5 notícias, resumos até 1000 chars.',
        userMessage
      );
      diag.minimaxArticlesReturned = result?.articles?.length || 0;
      diag.minimaxSample = result?.articles?.[0] ? { title_pt: result.articles[0].title_pt?.substring(0, 60) } : null;
      diag.steps.push('3-minimax-ok');
    } catch (e) {
      diag.minimaxError = e.message;
      diag.steps.push('3-minimax-fail');
      return res.json({ success: false, diag });
    }

    if (!result?.articles || result.articles.length === 0) {
      diag.steps.push('3-minimax-no-articles');
      const r = await pool.query('SELECT COUNT(*) as c FROM news');
      return res.json({ success: true, message: 'IA não retornou artigos', count: r.rows[0].c, diag });
    }

    // Step 4: Insert
    diag.steps.push('4-insert-start');
    let inserted = 0;
    const insertErrors = [];
    for (const article of result.articles) {
      try {
        if (!article.title_pt || !article.summary_pt) { insertErrors.push('skip: missing title/summary'); continue; }
        const mainTitle = article.original_titles?.[0] || article.title_en || article.title_pt;
        function computeTitleHash(title) {
          const normalized = title.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
          return crypto.createHash('sha256').update(normalized).digest('hex');
        }
        const titleHash = computeTitleHash(mainTitle);
        const translations = JSON.stringify({
          pt: { title: article.title_pt, summary: article.summary_pt },
          en: { title: article.title_en || article.title_pt, summary: article.summary_en || article.summary_pt },
        });
        await pool.query(
          `INSERT INTO news (title_hash, original_title, translations, source_urls, source_names, image_url, category, is_update, is_published, published_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (title_hash) DO NOTHING`,
          [titleHash, mainTitle.substring(0, 500), translations, JSON.stringify(article.source_urls || []), (article.source_names || []).join(', '), article.image_url || null, article.category || 'general', false, true, new Date()]
        );
        inserted++;
      } catch (e) {
        insertErrors.push(e.message);
      }
    }
    diag.inserted = inserted;
    diag.insertErrors = insertErrors;
    diag.steps.push('4-insert-done');

    const r = await pool.query('SELECT COUNT(*) as c FROM news');
    res.json({ success: true, message: `Fetch concluído: ${inserted} inseridas`, count: r.rows[0].c, diag });
  } catch (e) {
    diag.fatalError = e.message;
    diag.fatalStack = e.stack?.substring(0, 500);
    res.json({ success: false, diag });
  }
});

// Rotas públicas (não requerem autenticação)
router.get('/', getNews);
router.get('/:id', getNewsById);

module.exports = router;
