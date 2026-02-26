const { pgTable, serial, uuid, integer, timestamp, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { races } = require('./races');
const { users } = require('./users');

// Tabela de pontuações calculadas
// Após o admin cadastrar o resultado, o sistema calcula os pontos de cada usuário
const scores = pgTable('scores', {
  id: serial('id').primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  points: integer('points').notNull().default(0),
  calculatedAt: timestamp('calculated_at').defaultNow(),
}, (table) => ({
  leagueRaceUserUnique: unique().on(table.leagueId, table.raceId, table.userId),
}));

module.exports = { scores };
