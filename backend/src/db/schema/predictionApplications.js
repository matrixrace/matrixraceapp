const { pgTable, uuid, integer, serial, timestamp, unique } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { races } = require('./races');
const { users } = require('./users');

// Tabela que liga um palpite a uma liga
// Um palpite pode ser aplicado em várias ligas
const predictionApplications = pgTable('prediction_applications', {
  id: serial('id').primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  appliedAt: timestamp('applied_at').defaultNow(),
}, (table) => ({
  // Usuário só pode aplicar o palpite uma vez por liga/corrida
  uniqueApplication: unique().on(table.leagueId, table.raceId, table.userId),
}));

module.exports = { predictionApplications };
