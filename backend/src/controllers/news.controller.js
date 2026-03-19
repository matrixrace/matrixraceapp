const { pool } = require('../config/database');
const { successResponse } = require('../utils/helpers');

/**
 * GET /api/v1/news?page=1&limit=20&lang=pt
 * Lista notícias publicadas com paginação.
 */
async function getNews(req, res, next) {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const lang = req.query.lang || 'pt';
    const offset = (page - 1) * limit;

    const countResult = await pool.query(
      'SELECT COUNT(*)::int as count FROM news WHERE is_published = true'
    );
    const total = countResult.rows[0]?.count || 0;

    const dataResult = await pool.query(
      'SELECT * FROM news WHERE is_published = true ORDER BY published_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );

    const formatted = dataResult.rows.map(row => formatNewsItem(row, lang));

    res.json(successResponse({
      news: formatted,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    }));
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/v1/news/:id?lang=pt
 * Retorna uma notícia específica.
 */
async function getNewsById(req, res, next) {
  try {
    const id = parseInt(req.params.id);
    const lang = req.query.lang || 'pt';

    if (isNaN(id)) {
      return res.status(400).json({ success: false, message: 'ID inválido' });
    }

    const result = await pool.query(
      'SELECT * FROM news WHERE id = $1 AND is_published = true',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Notícia não encontrada' });
    }

    res.json(successResponse(formatNewsItem(result.rows[0], lang)));
  } catch (err) {
    next(err);
  }
}

/**
 * Formata um item de notícia extraindo a tradução no idioma solicitado.
 */
function formatNewsItem(row, lang) {
  let translations = {};
  try {
    translations = typeof row.translations === 'string' ? JSON.parse(row.translations) : row.translations;
  } catch (e) {
    translations = {};
  }

  let sourceUrls = [];
  try {
    const raw = row.source_urls || row.sourceUrls;
    sourceUrls = typeof raw === 'string' ? JSON.parse(raw) : (raw || []);
  } catch (e) {
    sourceUrls = [];
  }

  // Fallback: lang solicitado → en → pt → primeiro disponível
  const t = translations[lang] || translations['en'] || translations['pt'] || Object.values(translations)[0] || {};

  return {
    id: row.id,
    title: t.title || row.original_title || '',
    summary: t.summary || '',
    sourceUrls,
    sourceNames: row.source_names || '',
    imageUrl: row.image_url || null,
    category: row.category || 'general',
    isUpdate: row.is_update || false,
    publishedAt: row.published_at,
    createdAt: row.created_at,
  };
}

module.exports = { getNews, getNewsById };
