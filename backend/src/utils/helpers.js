// Funções utilitárias usadas em vários lugares do backend
const logger = require('./logger');

// Gera um código de convite aleatório (6 caracteres)
function generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Formata resposta de sucesso padrão
function successResponse(data, message = 'Sucesso') {
  return {
    success: true,
    message,
    data,
  };
}

// Formata resposta de erro padrão
function errorResponse(message = 'Erro', statusCode = 400) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

// Busca um setting do sistema (retorna valor padrão se não existir)
async function getSystemSetting(pool, key, defaultValue) {
  const result = await pool.query('SELECT value FROM system_settings WHERE key = $1', [key]);
  const value = result.rows.length > 0 ? parseInt(result.rows[0].value, 10) : defaultValue;
  logger.info(`[getSystemSetting] key=${key} value=${value} (from_db=${result.rows.length > 0})`);
  return value;
}

// Conta ligas ativas do usuário (exclui ligas onde TODAS as corridas terminaram)
async function countActiveLeagues(pool, userId) {
  const result = await pool.query(
    `SELECT COUNT(*) as total FROM league_members lm
     JOIN leagues l ON l.id = lm.league_id
     WHERE lm.user_id = $1 AND lm.status = 'active'
     AND (
       NOT EXISTS (SELECT 1 FROM league_races lr WHERE lr.league_id = l.id)
       OR EXISTS (
         SELECT 1 FROM league_races lr
         JOIN races r ON r.id = lr.race_id
         WHERE lr.league_id = l.id AND r.is_completed = false
       )
     )`,
    [userId]
  );
  const count = parseInt(result.rows[0].total, 10);
  logger.info(`[countActiveLeagues] userId=${userId} activeCount=${count}`);
  return count;
}

// Verifica limite de ligas. Retorna { allowed, maxJoin, activeCount }
async function checkLeagueJoinLimit(pool, userId) {
  const maxJoin = await getSystemSetting(pool, 'max_leagues_join', 10);
  const activeCount = await countActiveLeagues(pool, userId);
  const allowed = activeCount < maxJoin;
  if (!allowed) {
    logger.info(`[checkLeagueJoinLimit] BLOQUEADO userId=${userId} active=${activeCount} max=${maxJoin}`);
  }
  return { allowed, maxJoin, activeCount };
}

module.exports = {
  generateInviteCode,
  successResponse,
  errorResponse,
  getSystemSetting,
  countActiveLeagues,
  checkLeagueJoinLimit,
};
