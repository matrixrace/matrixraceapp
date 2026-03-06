const { pgTable, serial, varchar, integer, timestamp, unique } = require('drizzle-orm/pg-core');
const { races } = require('./races');
const { drivers } = require('./drivers');

// Tabela de resultados por sessao (FP1, FP2, FP3, Classificacao, Sprint, Corrida)
// Atualizada em tempo real pelo admin durante o fim de semana
const sessionResults = pgTable('session_results', {
  id: serial('id').primaryKey(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  sessionType: varchar('session_type', { length: 30 }).notNull(), // FP1, FP2, FP3, qualifying, sprint_qualifying, sprint, race
  driverId: integer('driver_id').references(() => drivers.id, { onDelete: 'cascade' }).notNull(),
  position: integer('position').notNull(),
  bestLapTime: varchar('best_lap_time', { length: 20 }),  // ex: "1:23.456"
  gap: varchar('gap', { length: 20 }),                      // ex: "+0.234" ou "LEADER"
  tireCompound: varchar('tire_compound', { length: 20 }),   // SOFT, MEDIUM, HARD, INTERMEDIATE, WET
  pitStops: integer('pit_stops').default(0),
  status: varchar('status', { length: 10 }),                // DNF, DNS, DSQ, null = finished
  updatedAt: timestamp('updated_at').defaultNow(),
}, (table) => ({
  raceSessionDriverUnique: unique().on(table.raceId, table.sessionType, table.driverId),
}));

module.exports = { sessionResults };
