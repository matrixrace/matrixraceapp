const cron = require('node-cron');
const logger = require('../utils/logger');
const { pool } = require('../config/database');
const autoRefresh = require('./autoRefresh.service');

const SESSION_WINDOW_HOURS = 3;
let _cronTask = null;

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
  try {
    const result = await pool.query(`
      SELECT * FROM races
      WHERE race_date BETWEEN NOW() - INTERVAL '3 days' AND NOW() + INTERVAL '3 days'
      AND is_completed = false
    `);

    const now = new Date();
    let liveSession = null;

    for (const race of result.rows) {
      const windows = buildSessionWindows(race);
      for (const w of windows) {
        if (now >= w.start && now <= w.end) {
          liveSession = { raceId: race.id, sessionType: w.type, raceName: race.name };
          break;
        }
      }
      if (liveSession) break;
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
          logger.info(`[Scheduler] Sessao ao vivo detectada: ${liveSession.sessionType} - ${liveSession.raceName}`);
          await autoRefresh.start(liveSession.raceId, liveSession.sessionType, 30000, 'scheduler');
        }
      }
    } else {
      // Nenhuma sessao ao vivo — para apenas se foi iniciado pelo scheduler
      if (status.active && status.source === 'scheduler') {
        logger.info('[Scheduler] Nenhuma sessao ao vivo — parando auto-refresh');
        await autoRefresh.stop();
      }
    }
  } catch (err) {
    logger.error(`[Scheduler] Erro ao verificar sessoes: ${err.message}`);
  }
}

function start() {
  if (_cronTask) return;

  // Roda a cada minuto
  _cronTask = cron.schedule('* * * * *', checkSessions);

  logger.info('[Scheduler] Agendador de sessoes iniciado (verifica a cada 1 min)');

  // Verifica imediatamente na inicializacao
  checkSessions();
}

function stop() {
  if (_cronTask) {
    _cronTask.stop();
    _cronTask = null;
    logger.info('[Scheduler] Agendador de sessoes parado');
  }
}

module.exports = { start, stop, checkSessions, buildSessionWindows };
