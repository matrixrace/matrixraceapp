const { pgTable, serial, uuid, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { users } = require('./users');

// Tabela de permissões de escrita no chat da liga
// Usada quando chatMode = 'selected': lista quem pode escrever além do líder
const leagueChatAllowed = pgTable('league_chat_allowed', {
  id: serial('id').primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
}, (table) => ({
  leagueUserUnique: unique().on(table.leagueId, table.userId),
}));

module.exports = { leagueChatAllowed };
