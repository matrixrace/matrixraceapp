const { pgTable, uuid, varchar, timestamp, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { users } = require('./users');

// Tabela de convites para ligas
// Quando alguém convida um amigo por email
const invitations = pgTable('invitations', {
  id: uuid('id').defaultRandom().primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  invitedBy: uuid('invited_by').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  email: varchar('email', { length: 255 }).notNull(),
  status: varchar('status', { length: 20 }).default('pending'), // pending, accepted, expired
  expiresAt: timestamp('expires_at'),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  leagueEmailUnique: unique().on(table.leagueId, table.email),
}));

module.exports = { invitations };
