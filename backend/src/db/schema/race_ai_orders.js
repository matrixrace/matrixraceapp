const { pgTable, uuid, integer, unique } = require('drizzle-orm/pg-core');
const { races } = require('./races');
const { drivers } = require('./drivers');

// Ordem de pilotos definida pelo admin para o autocompletar "Por IA"
// Uma entrada por piloto por corrida, com a posição prevista
const raceAiOrders = pgTable('race_ai_orders', {
  id: uuid('id').defaultRandom().primaryKey(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  driverId: integer('driver_id').references(() => drivers.id, { onDelete: 'cascade' }).notNull(),
  predictedPosition: integer('predicted_position').notNull(),
}, (table) => ({
  uniqueDriver: unique().on(table.raceId, table.driverId),
  uniquePosition: unique().on(table.raceId, table.predictedPosition),
}));

module.exports = { raceAiOrders };
