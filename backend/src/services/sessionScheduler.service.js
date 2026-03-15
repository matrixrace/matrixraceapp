const cron = require('node-cron');
const logger = require('../utils/logger');
const { pool } = require('../config/database');
const autoRefresh = require('./autoRefresh.service');
const https = require('https');
const http = require('http');

const SESSION_WINDOW_HOURS = 3;
let _cronTask = null;
let _keepAliveCron = null;
let _lastCheck = null;
let _checkCount = 0;
let _lastLiveSession = null;

// Monta janelas de sessao para uma corrida
function buildSessionWindows(race) {
  const WINDOW_MS = SESSION_WINDOW_HOURS * 60 * 60 * 1000;
  const windows = [];

  const addWindow = (type, date) => {
    if (!date) return;
    const start = new Date(date);
    if (isNaN(start.getTime())) return;
    const end = new Date(start.getTime() + WINDOW_MS);
    windows.push({ type, start, end });
  };

  addWindow('FP1', race.fp1_date);

  if (race.is_sprint_weekend) {
    addWindow('sprint_qualifying', race.sprint_qualifying_date);
    addWindow('sprint', race.sprint_date);
  } else {
    // Estimar FP2: fp1 + 3.5h
    if (race.fp1_date) {
      const fp2Start = new Date(new Date(race.fp1_date).getTime() + 3.5 * 3600000);
      addWindow('FP2', fp2Start);
    }
    // Estimar FP3: qualifying - 4h
    if (race.qualifying_date) {
      const fp3Start = new Date(new Date(race.qualifying_date).getTime() - 4 * 3600000);
      addWindow('FP3', fp3Start);
    }
  }

  addWindow('qualifying', race.qualifying_date);
  addWindow('race', race.race_date);

  return windows;
}

// Verifica se alguma sessao esta ao vivo e gerencia o auto-refresh
async function checkSessions() {
  _lastCheck = new Date().toISOString();
  _checkCount++;

  try {
    const result = await pool.query(`
      SELECT * FROM races
      WHERE race_date BETWEEN NOW() - INTERVAL '3 days' AND NOW() + INTERVAL '3 days'
      AND is_completed = false
    `);

    if (result.rows.length === 0) {
      // Log a cada 60 verificacoes (~1h) para nao poluir
      if (_checkCount % 60 === 0) {
        logger.info('[Scheduler] Nenhuma corrida ativa nos proximos 3 dias');
      }
      // Garante que auto-refresh do scheduler esta parado
      const status = autoRefresh.getStatus();
      if (status.active && status.source === 'scheduler') {
        logger.info('[Scheduler] Nenhuma corrida ativa — parando auto-refresh');
        await autoRefresh.stop();
      }
      return;
    }

    const now = new Date();
    let liveSession = null;

    for (const race of result.rows) {
      const windows = buildSessionWindows(race);

      // Log detalhado das janelas na primeira verificacao ou a cada 30 min
      if (_checkCount === 1 || _checkCount % 30 === 0) {
        const windowInfo = windows.map(w =>
          `${w.type}: ${w.start.toISOString()} → ${w.end.toISOString()}`
        ).join(' | ');
        logger.info(`[Scheduler] Corrida ${race.name} (id=${race.id}, sprint=${race.is_sprint_weekend}): ${windowInfo}`);

        // Alerta se datas de sprint estao faltando para corrida sprint
        if (race.is_sprint_weekend) {
          if (!race.sprint_qualifying_date) {
            logger.warn(`[Scheduler] ALERTA: Corrida sprint ${race.name} SEM sprint_qualifying_date!`);
          }
          if (!race.sprint_date) {
            logger.warn(`[Scheduler] ALERTA: Corrida sprint ${race.name} SEM sprint_date!`);
          }
        }
      }

      for (const w of windows) {
        if (now >= w.start && now <= w.end) {
          liveSession = { raceId: race.id, sessionType: w.type, raceName: race.name };
          break;
        }
      }
      if (liveSession) break;

      // Log se estamos perto de uma janela (dentro de 10 min)
      const TEN_MIN = 10 * 60 * 1000;
      for (const w of windows) {
        const timeToStart = w.start.getTime() - now.getTime();
        if (timeToStart > 0 && timeToStart <= TEN_MIN) {
          logger.info(`[Scheduler] Sessao ${w.type} de ${race.name} comeca em ${Math.round(timeToStart / 60000)} min`);
        }
      }
    }

    const status = autoRefresh.getStatus();

    if (liveSession) {
      // Sessao ao vivo encontrada
      const sameSession = status.active
        && status.raceId === liveSession.raceId
        && status.sessionType === liveSession.sessionType;

      if (!sameSession) {
        // So inicia se nao ha refresh manual ativo
        if (!status.active || status.source === 'scheduler') {
          logger.info(`[Scheduler] Sessao ao vivo detectada: ${liveSession.sessionType} - ${liveSession.raceName} (raceId=${liveSession.raceId})`);
          await autoRefresh.start(liveSession.raceId, liveSession.sessionType, 30000, 'scheduler');
        } else {
          logger.info(`[Scheduler] Sessao ao vivo detectada mas auto-refresh manual ativo — nao substituindo`);
        }
      }

      _lastLiveSession = liveSession;
    } else {
      // Nenhuma sessao ao vivo — verifica catch-up de sessoes recentemente encerradas
      await catchUpMissedSessions(result.rows);

      // Para auto-refresh do scheduler se estava ativo
      if (status.active && status.source === 'scheduler') {
        logger.info('[Scheduler] Nenhuma sessao ao vivo — parando auto-refresh');
        await autoRefresh.stop();
      }
      _lastLiveSession = null;
    }
  } catch (err) {
    logger.error(`[Scheduler] Erro ao verificar sessoes: ${err.message}`);
  }
}

// Catch-up: tenta preencher sessoes que terminaram recentemente mas nao tem resultados
async function catchUpMissedSessions(races) {
  const now = new Date();
  const ONE_HOUR = 60 * 60 * 1000;

  for (const race of races) {
    const windows = buildSessionWindows(race);

    for (const w of windows) {
      // Sessao terminou ha menos de 6 horas
      const endedAgo = now.getTime() - w.end.getTime();
      if (endedAgo > 0 && endedAgo < 6 * ONE_HOUR) {
        // Verifica se ja tem resultados para esta sessao
        const existing = await pool.query(
          'SELECT COUNT(*) as cnt FROM session_results WHERE race_id = $1 AND session_type = $2',
          [race.id, w.type]
        );

        if (parseInt(existing.rows[0].cnt) === 0) {
          logger.info(`[Scheduler] Catch-up: sessao ${w.type} de ${race.name} terminou ha ${Math.round(endedAgo / 60000)} min sem resultados — tentando preencher`);
          try {
            const { doSessionRefresh } = require('../controllers/live.controller');
            const result = await doSessionRefresh(race.id, w.type);
            logger.info(`[Scheduler] Catch-up OK: ${w.type} de ${race.name} — ${result.count} pilotos`);
          } catch (err) {
            logger.warn(`[Scheduler] Catch-up falhou para ${w.type} de ${race.name}: ${err.message}`);
          }
        }
      }
    }
  }
}

// Keep-alive: faz ping no proprio servidor para evitar que Railway suspenda o container
function selfPing() {
  const port = process.env.PORT || 3000;
  const url = process.env.RAILWAY_PUBLIC_DOMAIN
    ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}/api/v1/health`
    : `http://localhost:${port}/api/v1/health`;

  const client = url.startsWith('https') ? https : http;

  client.get(url, { timeout: 10000 }, (resp) => {
    let data = '';
    resp.on('data', c => { data += c; });
    resp.on('end', () => {
      logger.info(`[KeepAlive] Ping OK (status=${resp.statusCode})`);
    });
  }).on('error', (err) => {
    // Tenta localhost como fallback
    if (!url.includes('localhost')) {
      http.get(`http://localhost:${port}/api/v1/health`, { timeout: 5000 }, () => {
        logger.info('[KeepAlive] Ping localhost OK');
      }).on('error', () => {
        logger.warn('[KeepAlive] Ping falhou: ' + err.message);
      });
    } else {
      logger.warn('[KeepAlive] Ping falhou: ' + err.message);
    }
  });
}

function start() {
  if (_cronTask) return;

  // Roda a cada minuto
  _cronTask = cron.schedule('* * * * *', checkSessions);

  logger.info('[Scheduler] Agendador de sessoes iniciado (verifica a cada 1 min)');

  // Keep-alive a cada 10 minutos para evitar container sleeping
  _keepAliveCron = cron.schedule('*/10 * * * *', selfPing);
  logger.info('[Scheduler] Keep-alive iniciado (ping a cada 10 min)');

  // Verifica imediatamente na inicializacao
  checkSessions();
}

function stop() {
  if (_cronTask) {
    _cronTask.stop();
    _cronTask = null;
    logger.info('[Scheduler] Agendador de sessoes parado');
  }
  if (_keepAliveCron) {
    _keepAliveCron.stop();
    _keepAliveCron = null;
  }
}

// Retorna diagnostico do scheduler
function getDiagnostics() {
  return {
    running: !!_cronTask,
    keepAlive: !!_keepAliveCron,
    lastCheck: _lastCheck,
    checkCount: _checkCount,
    lastLiveSession: _lastLiveSession,
    autoRefresh: autoRefresh.getStatus(),
  };
}

module.exports = { start, stop, checkSessions, buildSessionWindows, getDiagnostics };
