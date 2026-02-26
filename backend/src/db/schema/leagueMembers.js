const { pgTable, serial, uuid, varchar, boolean, timestamp, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { users } = require('./users');

// Tabela de membros de cada liga
// Cada registro = um usuário que entrou em uma liga
const leagueMembers = pgTable('league_members', {
  id: serial('id').primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  status: varchar('status', { length: 20 }).default('active'), // active | pending
  hasPaid: boolean('has_paid').default(false), // Para ligas pagas (futuro)
  joinedAt: timestamp('joined_at').defaultNow(),
}, (table) => ({
  leagueUserUnique: unique().on(table.leagueId, table.userId),
}));

module.exports = { leagueMembers };
