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
let _lastDiag = null;
let _runHistory = []; // últimas 10 execuções

const SYSTEM_PROMPT = `Você é um editor profissional de notícias de Fórmula 1 para um público brasileiro. Receba uma lista de artigos recentes de diversos portais de F1.

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

REGRAS CRÍTICAS DE IDIOMA:
- Os campos title_pt e summary_pt devem ser 100% em PORTUGUÊS BRASILEIRO. Nenhuma palavra em inglês deve aparecer, exceto nomes próprios (pessoas, equipes, circuitos) e termos técnicos amplamente usados em F1 (pit stop, safety car, pole position, sprint, undercut, DRS).
- Traduza TUDO para português: frases, expressões e citações. Nunca deixe trechos em inglês misturados no texto português.
- Revise cada resumo em português antes de finalizar: verifique se há frases em inglês esquecidas, erros gramaticais, concordância verbal e nominal, e fluidez do texto.
- Use linguagem jornalística natural em português brasileiro, como se fosse publicado no Globo Esporte ou UOL Esporte.
- Os campos title_en e summary_en devem ser 100% em inglês.

OUTRAS REGRAS:
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
async function fetchAndProcessNews(options = {}) {
  const diag = { steps: [], inserted: 0, insertErrors: [] };

  if (_isRunning) {
    logger.info('[NewsScheduler] Já existe um ciclo em execução, pulando...');
    diag.steps.push('skipped-already-running');
    return diag;
  }

  _isRunning = true;
  _lastRun = new Date().toISOString();
  _runCount++;

  try {
    logger.info('[NewsScheduler] Iniciando ciclo de busca de notícias...');

    // 1. Buscar RSS feeds (últimas 8h para margem de segurança com ciclo de 4h)
    diag.steps.push('1-rss-start');
    const articles = await fetchAllFeeds(8);
    diag.rssCount = articles.length;
    diag.rssSample = articles.slice(0, 5).map(a => ({ title: a.title, source: a.sourceName }));
    diag.steps.push('1-rss-ok');
    logger.info(`[NewsScheduler] ${articles.length} artigos encontrados nos feeds`);

    if (articles.length === 0) {
      logger.info('[NewsScheduler] Nenhum artigo novo nos feeds. Encerrando ciclo.');
      diag.steps.push('1-rss-empty');
      return diag;
    }

    // 2. Deduplicação pré-IA
    diag.steps.push('2-dedup-start');
    const existingHashes = await getRecentHashes();
    diag.existingHashCount = existingHashes.size;
    const newArticles = articles.filter(a => {
      const hash = computeTitleHash(a.title);
      return !existingHashes.has(hash);
    });
    diag.afterDedupCount = newArticles.length;
    diag.steps.push('2-dedup-ok');

    logger.info(`[NewsScheduler] ${newArticles.length} artigos após deduplicação (${articles.length - newArticles.length} já conhecidos)`);

    if (newArticles.length === 0) {
      logger.info('[NewsScheduler] Todos os artigos já foram processados. Encerrando ciclo.');
      diag.steps.push('2-dedup-all-known');
      return diag;
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
    diag.steps.push('3-minimax-start');
    diag.minimaxInputArticles = batch.length;
    logger.info(`[NewsScheduler] Enviando ${batch.length} artigos para análise IA...`);

    let result;
    try {
      result = await callMiniMaxJSON(SYSTEM_PROMPT, userMessage);
    } catch (mmErr) {
      diag.minimaxError = mmErr.message;
      diag.steps.push('3-minimax-fail');
      logger.error(`[NewsScheduler] Erro MiniMax: ${mmErr.message}`);
      return diag;
    }

    if (!result?.articles || !Array.isArray(result.articles)) {
      logger.warn('[NewsScheduler] IA retornou formato inválido. Encerrando ciclo.');
      diag.minimaxInvalid = true;
      diag.steps.push('3-minimax-invalid');
      return diag;
    }

    diag.minimaxArticlesReturned = result.articles.length;
    diag.minimaxSample = result.articles[0] ? { title_pt: result.articles[0].title_pt } : null;
    diag.steps.push('3-minimax-ok');

    logger.info(`[NewsScheduler] IA retornou ${result.articles.length} notícias processadas`);

    // 6. Inserir no banco de dados
    diag.steps.push('4-insert-start');
    let inserted = 0;
    for (const article of result.articles) {
      try {
        if (!article.title_pt || !article.summary_pt) continue;

        const mainTitle = article.original_titles?.[0] || article.title_en || article.title_pt;
        const titleHash = computeTitleHash(mainTitle);

        const translations = JSON.stringify({
          pt: { title: article.title_pt, summary: article.summary_pt },
          en: { title: article.title_en || article.title_pt, summary: article.summary_en || article.summary_pt },
        });

        const insertResult = await pool.query(
          `INSERT INTO news (title_hash, original_title, translations, source_urls, source_names, image_url, category, is_update, is_published, published_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (title_hash) DO NOTHING
           RETURNING id`,
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

        if (insertResult.rowCount > 0) {
          inserted++;
        }
      } catch (err) {
        diag.insertErrors.push(err.message);
        logger.warn(`[NewsScheduler] Erro ao inserir notícia: ${err.message}`);
      }
    }

    diag.inserted = inserted;
    diag.steps.push('4-insert-done');
    logger.info(`[NewsScheduler] Ciclo concluído: ${inserted} notícias inseridas`);
    _lastDiag = diag;
    _runHistory.push({ time: _lastRun, inserted, steps: diag.steps.join(',') });
    if (_runHistory.length > 10) _runHistory.shift();
    return diag;
  } catch (err) {
    diag.error = err.message;
    logger.error(`[NewsScheduler] Erro no ciclo: ${err.message}`);
    _lastDiag = diag;
    _runHistory.push({ time: _lastRun, error: err.message });
    if (_runHistory.length > 10) _runHistory.shift();
    return diag;
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
    lastDiag: _lastDiag,
    history: _runHistory,
  };
}

module.exports = { start, stop, fetchAndProcessNews, getDiagnostics };
