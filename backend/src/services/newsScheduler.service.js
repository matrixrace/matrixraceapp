const cron = require('node-cron');
const crypto = require('crypto');
const { pool } = require('../config/database');
const { fetchAllFeeds } = require('../utils/rss');
const { callMiniMaxJSON } = require('../utils/minimax');
const logger = require('../utils/logger');

let _cronTask = null;
let _lastRun = null;
let _runCount = 0;
let _isRunning = false;

const SYSTEM_PROMPT = `Você é um editor de notícias de Fórmula 1. Receba uma lista de artigos recentes de diversos portais de F1.

Sua tarefa:
1. Filtre apenas notícias realmente importantes e relevantes sobre F1 (ignore fofoca sem substância, conteúdo patrocinado, artigos sobre e-sports/F2/F3 a menos que impactem F1 diretamente).
2. Agrupe artigos que cobrem o mesmo evento ou assunto.
3. Para cada grupo de notícias importante, gere:
   - title_pt: título em português brasileiro (máximo 100 caracteres, impactante)
   - summary_pt: resumo em português brasileiro (máximo 1000 caracteres, informativo e claro)
   - title_en: título em inglês (máximo 100 caracteres)
   - summary_en: resumo em inglês (máximo 1000 caracteres)
   - category: classificação — usar um destes valores: race, transfer, technical, regulation, general
   - original_titles: array com os títulos originais dos artigos usados
   - source_names: array com os nomes dos portais fonte
   - source_urls: array com as URLs dos artigos fonte
   - image_url: URL da melhor imagem disponível (ou null)

4. Retorne APENAS JSON válido no formato:
{ "articles": [ { "title_pt": "...", "summary_pt": "...", "title_en": "...", "summary_en": "...", "category": "...", "original_titles": [...], "source_names": [...], "source_urls": [...], "image_url": "..." } ] }

Se não houver nenhuma notícia relevante, retorne: { "articles": [] }

IMPORTANTE:
- Cada resumo deve ter NO MÁXIMO 1000 caracteres.
- Selecione apenas as notícias mais importantes (máximo 5 por ciclo).
- Se vários artigos cobrem o mesmo assunto, combine-os em uma única entrada.`;

/**
 * Gera hash SHA-256 normalizado do título para deduplicação.
 */
function computeTitleHash(title) {
  const normalized = title
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // remove diacríticos
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

/**
 * Busca hashes de notícias dos últimos 7 dias para deduplicação.
 */
async function getRecentHashes() {
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const result = await pool.query(
    'SELECT title_hash FROM news WHERE published_at >= $1',
    [sevenDaysAgo]
  );
  return new Set(result.rows.map(r => r.title_hash));
}

/**
 * Executa o ciclo completo de busca, análise e inserção de notícias.
 */
async function fetchAndProcessNews() {
  if (_isRunning) {
    logger.info('[NewsScheduler] Já existe um ciclo em execução, pulando...');
    return;
  }

  _isRunning = true;
  _lastRun = new Date().toISOString();
  _runCount++;

  try {
    logger.info('[NewsScheduler] Iniciando ciclo de busca de notícias...');

    // 1. Buscar RSS feeds (últimas 5h para margem de segurança)
    const articles = await fetchAllFeeds(5);
    logger.info(`[NewsScheduler] ${articles.length} artigos encontrados nos feeds`);

    if (articles.length === 0) {
      logger.info('[NewsScheduler] Nenhum artigo novo nos feeds. Encerrando ciclo.');
      return;
    }

    // 2. Deduplicação pré-IA
    const existingHashes = await getRecentHashes();
    const newArticles = articles.filter(a => {
      const hash = computeTitleHash(a.title);
      return !existingHashes.has(hash);
    });

    logger.info(`[NewsScheduler] ${newArticles.length} artigos após deduplicação (${articles.length - newArticles.length} já conhecidos)`);

    if (newArticles.length === 0) {
      logger.info('[NewsScheduler] Todos os artigos já foram processados. Encerrando ciclo.');
      return;
    }

    // 3. Limitar batch para controle de custo (max 50 artigos)
    const batch = newArticles.slice(0, 50);

    // 4. Preparar input para a IA
    const userMessage = JSON.stringify(
      batch.map(a => ({
        title: a.title,
        description: a.description?.substring(0, 300) || '',
        source: a.sourceName,
        url: a.link,
        date: a.pubDate?.toISOString(),
      }))
    );

    // 5. Chamar MiniMax
    logger.info(`[NewsScheduler] Enviando ${batch.length} artigos para análise IA...`);
    const result = await callMiniMaxJSON(SYSTEM_PROMPT, userMessage);

    if (!result?.articles || !Array.isArray(result.articles)) {
      logger.warn('[NewsScheduler] IA retornou formato inválido. Encerrando ciclo.');
      return;
    }

    logger.info(`[NewsScheduler] IA retornou ${result.articles.length} notícias processadas`);

    // 6. Inserir no banco de dados
    let inserted = 0;
    for (const article of result.articles) {
      try {
        if (!article.title_pt || !article.summary_pt) continue;

        const mainTitle = article.original_titles?.[0] || article.title_en || article.title_pt;
        const titleHash = computeTitleHash(mainTitle);

        // Verificar se já existe (ON CONFLICT)
        const translations = JSON.stringify({
          pt: { title: article.title_pt, summary: article.summary_pt },
          en: { title: article.title_en || article.title_pt, summary: article.summary_en || article.summary_pt },
        });

        await pool.query(
          `INSERT INTO news (title_hash, original_title, translations, source_urls, source_names, image_url, category, is_update, is_published, published_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (title_hash) DO NOTHING`,
          [
            titleHash,
            mainTitle.substring(0, 500),
            translations,
            JSON.stringify(article.source_urls || []),
            (article.source_names || []).join(', '),
            article.image_url || null,
            article.category || 'general',
            false,
            true,
            new Date(),
          ]
        );

        inserted++;
      } catch (err) {
        logger.warn(`[NewsScheduler] Erro ao inserir notícia: ${err.message}`);
      }
    }

    logger.info(`[NewsScheduler] Ciclo concluído: ${inserted} notícias inseridas`);
  } catch (err) {
    logger.error(`[NewsScheduler] Erro no ciclo: ${err.message}`);
  } finally {
    _isRunning = false;
  }
}

/**
 * Inicia o agendador de notícias (a cada 4 horas).
 */
function start() {
  if (_cronTask) return;

  // Roda a cada 4 horas: minuto 5 das horas 0, 4, 8, 12, 16, 20
  _cronTask = cron.schedule('5 */4 * * *', fetchAndProcessNews);
  logger.info('[NewsScheduler] Agendador de notícias iniciado (a cada 4 horas)');

  // Primeira execução com delay de 45s para o servidor estabilizar
  setTimeout(() => {
    logger.info('[NewsScheduler] Executando primeira busca de notícias...');
    fetchAndProcessNews();
  }, 45000);
}

/**
 * Para o agendador.
 */
function stop() {
  if (_cronTask) {
    _cronTask.stop();
    _cronTask = null;
    logger.info('[NewsScheduler] Agendador de notícias parado');
  }
}

/**
 * Retorna diagnósticos do agendador.
 */
function getDiagnostics() {
  return {
    running: !!_cronTask,
    isProcessing: _isRunning,
    lastRun: _lastRun,
    runCount: _runCount,
    schedule: '5 */4 * * *',
  };
}

module.exports = { start, stop, fetchAndProcessNews, getDiagnostics };
