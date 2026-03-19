const { db } = require('../config/database');
const { news } = require('../db/schema');
const { desc, eq, sql, and } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');

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

    // Total de notícias publicadas
    const [{ count }] = await db
      .select({ count: sql`COUNT(*)::int` })
      .from(news)
      .where(eq(news.isPublished, true));

    // Buscar notícias com paginação
    const rows = await db
      .select()
      .from(news)
      .where(eq(news.isPublished, true))
      .orderBy(desc(news.publishedAt))
      .limit(limit)
      .offset(offset);

    // Formatar para o idioma solicitado
    const formatted = rows.map(row => formatNewsItem(row, lang));

    res.json(successResponse({
      news: formatted,
      total: count,
      page,
      limit,
      totalPages: Math.ceil(count / limit),
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
    const { id } = req.params;
    const lang = req.query.lang || 'pt';

    const [row] = await db
      .select()
      .from(news)
      .where(and(eq(news.id, parseInt(id)), eq(news.isPublished, true)));

    if (!row) {
      return res.status(404).json(errorResponse('Notícia não encontrada'));
    }

    res.json(successResponse(formatNewsItem(row, lang)));
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
    sourceUrls = typeof row.sourceUrls === 'string' ? JSON.parse(row.sourceUrls) : row.sourceUrls;
  } catch (e) {
    sourceUrls = [];
  }

  // Fallback: lang solicitado → en → pt → primeiro disponível
  const t = translations[lang] || translations['en'] || translations['pt'] || Object.values(translations)[0] || {};

  return {
    id: row.id,
    title: t.title || row.originalTitle || '',
    summary: t.summary || '',
    sourceUrls,
    sourceNames: row.sourceNames || '',
    imageUrl: row.imageUrl,
    category: row.category || 'general',
    isUpdate: row.isUpdate || false,
    publishedAt: row.publishedAt,
    createdAt: row.createdAt,
  };
}

module.exports = { getNews, getNewsById };
