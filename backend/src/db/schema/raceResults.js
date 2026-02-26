const { pgTable, serial, integer, timestamp, unique } = require('drizzle-orm/pg-core');
const { races } = require('./races');
const { drivers } = require('./drivers');

// Tabela de resultados reais das corridas
// O admin cadastra aqui a posição real de cada piloto
const raceResults = pgTable('race_results', {
  id: serial('id').primaryKey(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  driverId: integer('driver_id').references(() => drivers.id, { onDelete: 'cascade' }).notNull(),
  position: integer('position').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
}, (table) => ({
  racePositionUnique: unique().on(table.raceId, table.position),
  raceDriverUnique: unique().on(table.raceId, table.driverId),
}));

module.exports = { raceResults };
