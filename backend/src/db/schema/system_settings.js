const { pgTable, varchar, text } = require('drizzle-orm/pg-core');

// Configurações globais do sistema, editáveis pelo admin
// Ex: max_leagues_join, max_leagues_create
const systemSettings = pgTable('system_settings', {
  key: varchar('key', { length: 100 }).primaryKey(),
  value: text('value').notNull(),
});

module.exports = { systemSettings };
