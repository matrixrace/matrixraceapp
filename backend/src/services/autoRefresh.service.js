const logger = require('../utils/logger');
const { pool } = require('../config/database');
const { getIo } = require('../config/socket');

const MAX_CONSECUTIVE_ERRORS = 10;

let _intervalHandle = null;
let _state = {
  active: false,
  raceId: null,
  sessionType: null,
  intervalMs: 30000,
  errorCount: 0,
  lastRefresh: null,
  lastError: null,
};

// Persiste estado no system_settings
async function persistState() {
  try {
    const keys = {
      auto_refresh_active: String(_state.active),
      auto_refresh_race_id: String(_state.raceId || ''),
      auto_refresh_session_type: _state.sessionType || '',
      auto_refresh_interval: String(_state.intervalMs),
    };
    for (const [key, value] of Object.entries(keys)) {
      await pool.query(
        `INSERT INTO system_settings (key, value) VALUES ($1, $2)
         ON CONFLICT (key) DO UPDATE SET value = $2`,
        [key, value]
      );
    }
  } catch (err) {
    logger.error('Erro ao persistir estado do auto-refresh:', err.message);
  }
}

// Executa um ciclo de refresh
async function doRefreshCycle() {
  if (!_state.active || !_state.raceId || !_state.sessionType) return;

  try {
    // Importa aqui para evitar circular dependency
    const { doSessionRefresh } = require('../controllers/live.controller');
    const result = await doSessionRefresh(_state.raceId, _state.sessionType);

    _state.errorCount = 0;
    _state.lastRefresh = new Date().toISOString();
    _state.lastError = null;

    logger.info(`[AutoRefresh] OK: ${result.count} pilotos atualizados (race=${_state.raceId}, session=${_state.sessionType})`);
  } catch (err) {
    _state.errorCount++;
    _state.lastError = err.message;
    logger.error(`[AutoRefresh] Erro #${_state.errorCount}: ${err.message}`);

    // Para automaticamente apos muitos erros consecutivos
    if (_state.errorCount >= MAX_CONSECUTIVE_ERRORS) {
      logger.error(`[AutoRefresh] ${MAX_CONSECUTIVE_ERRORS} erros consecutivos — parando automaticamente`);
      await stop();

      // Notifica admin via socket
      const io = getIo();
      if (io) {
        io.emit('auto_refresh_stopped', {
          reason: `${MAX_CONSECUTIVE_ERRORS} erros consecutivos`,
          lastError: err.message,
        });
      }
    }
  }
}

async function start(raceId, sessionType, intervalMs = 30000) {
  // Para qualquer refresh anterior
  if (_intervalHandle) {
    clearInterval(_intervalHandle);
    _intervalHandle = null;
  }

  _state = {
    active: true,
    raceId,
    sessionType,
    intervalMs,
    errorCount: 0,
    lastRefresh: null,
    lastError: null,
  };

  await persistState();

  // Executa imediatamente o primeiro refresh
  doRefreshCycle();

  // Inicia timer
  _intervalHandle = setInterval(doRefreshCycle, intervalMs);

  logger.info(`[AutoRefresh] Iniciado: raceId=${raceId} session=${sessionType} intervalo=${intervalMs}ms`);
}

async function stop() {
  if (_intervalHandle) {
    clearInterval(_intervalHandle);
    _intervalHandle = null;
  }

  _state.active = false;
  await persistState();

  logger.info('[AutoRefresh] Parado');
}

function getStatus() {
  return { ..._state };
}

function isActive() {
  return _state.active;
}

// Chamado no startup do servidor para retomar auto-refresh se estava ativo
async function resumeIfActive() {
  try {
    const result = await pool.query(
      "SELECT key, value FROM system_settings WHERE key LIKE 'auto_refresh_%'"
    );

    const settings = {};
    for (const row of result.rows) {
      settings[row.key] = row.value;
    }

    if (settings.auto_refresh_active === 'true') {
      const raceId = parseInt(settings.auto_refresh_race_id);
      const sessionType = settings.auto_refresh_session_type;
      const intervalMs = parseInt(settings.auto_refresh_interval) || 30000;

      if (raceId && sessionType) {
        logger.info(`[AutoRefresh] Retomando: raceId=${raceId} session=${sessionType} intervalo=${intervalMs}ms`);
        await start(raceId, sessionType, intervalMs);
      }
    }
  } catch (err) {
    logger.error('[AutoRefresh] Erro ao retomar:', err.message);
  }
}

module.exports = {
  start,
  stop,
  getStatus,
  isActive,
  resumeIfActive,
};
