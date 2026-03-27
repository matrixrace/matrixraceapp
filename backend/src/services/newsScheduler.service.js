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

const SYSTEM_PROMPT = `Você é um jornalista esportivo brasileiro especializado em Fórmula 1, trabalhando para um grande portal brasileiro (como Globo Esporte ou ge.globo.com). Você recebe artigos em inglês de portais internacionais e deve produzir notícias de alta qualidade em português brasileiro.

TAREFA:
1. Filtre apenas notícias realmente importantes sobre F1 (ignore fofoca, conteúdo patrocinado, e-sports, F2/F3).
2. Agrupe artigos sobre o mesmo assunto em uma única notícia.
3. Para cada notícia importante, gere TODOS os campos abaixo:
   - title_pt, summary_pt: em português brasileiro
   - title_en, summary_en: em inglês
   - category: race | transfer | technical | regulation | general
   - original_titles: array com títulos originais
   - source_names: array com nomes dos portais
   - source_urls: array com URLs dos artigos
   - image_url: URL da imagem (ou null)

FORMATO DE RESPOSTA (JSON puro, sem markdown):
{ "articles": [ { "title_pt": "...", "summary_pt": "...", "title_en": "...", "summary_en": "...", "category": "...", "original_titles": [...], "source_names": [...], "source_urls": [...], "image_url": null } ] }

Se não houver notícias relevantes: { "articles": [] }

REGRAS DE TRADUÇÃO PARA PORTUGUÊS (CRÍTICO — SIGA RIGOROSAMENTE):
- Escreva como um jornalista brasileiro nativo. O texto em português deve soar como se tivesse sido escrito originalmente em português, NÃO como uma tradução.
- PROIBIDO usar palavras em inglês no texto português, com ÚNICA exceção de: nomes próprios (Lewis Hamilton, Ferrari, Silverstone) e termos técnicos universais de F1 (pit stop, safety car, pole position, sprint, DRS, undercut).
- PROIBIDO criar verbos aportuguesados do inglês (ex: "channelou", "performou", "crashou"). Use verbos portugueses reais.
- PROIBIDO deixar frases ou trechos em inglês misturados no texto português.
- Traduza expressões idiomáticas para equivalentes naturais em português. Não traduza literalmente.
- REVISÃO OBRIGATÓRIA: Antes de finalizar, releia cada title_pt e summary_pt e verifique:
  (a) Há alguma palavra em inglês que não é nome próprio ou termo técnico de F1?
  (b) A gramática está correta? (concordância verbal, nominal, regência)
  (c) O texto soa natural para um leitor brasileiro?
  Se qualquer resposta for "não", reescreva.

EXEMPLOS DE TRADUÇÃO CORRETA:
- "Hamilton channels his inner Han Lue" → "Hamilton faz pose inspirada no personagem Han Lue"
- "Bearman has been one of the most impressive performers" → "Bearman tem sido um dos destaques"
- "The team is looking to bounce back" → "A equipe busca se recuperar"

OUTRAS REGRAS:
- Máximo 1000 caracteres por resumo.
- Máximo 5 notícias por ciclo.
- Combine artigos sobre o mesmo assunto.`;

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
