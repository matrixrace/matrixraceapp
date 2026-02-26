const { pgTable, serial, uuid, integer, timestamp, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { races } = require('./races');

// Tabela intermediária: quais corridas fazem parte de cada liga
// Uma liga pode ter várias corridas e uma corrida pode estar em várias ligas
const leagueRaces = pgTable('league_races', {
  id: serial('id').primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
}, (table) => ({
  leagueRaceUnique: unique().on(table.leagueId, table.raceId),
}));

module.exports = { leagueRaces };
