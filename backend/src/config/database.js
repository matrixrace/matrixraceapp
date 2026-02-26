const { drizzle } = require('drizzle-orm/node-postgres');
const { Pool } = require('pg');
const config = require('./environment');
const logger = require('../utils/logger');
const schema = require('../db/schema');

// Cria pool de conexões com o PostgreSQL
const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 20, // Máximo de conexões simultâneas
  idleTimeoutMillis: 30000, // Fecha conexões ociosas após 30s
  connectionTimeoutMillis: 5000, // Timeout para conectar: 5s
  ssl: config.nodeEnv === 'production' ? { rejectUnauthorized: false } : false,
});

// Evento: quando conecta com sucesso
pool.on('connect', () => {
  logger.info('Conectado ao PostgreSQL');
});

// Evento: quando ocorre erro
pool.on('error', (err) => {
  logger.error('Erro no PostgreSQL:', err.message);
});

// Cria instância do Drizzle ORM
const db = drizzle(pool, { schema });

// Função para testar conexão
async function testConnection() {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    logger.info(`Banco de dados conectado: ${result.rows[0].now}`);
    return true;
  } catch (error) {
    logger.error('Erro ao conectar no banco de dados:', error.message);
    return false;
  }
}

module.exports = { db, pool, testConnection };
