const { pgTable, serial, varchar, integer, boolean, timestamp, unique } = require('drizzle-orm/pg-core');

// Tabela de corridas (ex: GP do Brasil 2026, GP de Monaco 2026)
const races = pgTable('races', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 100 }).notNull(),
  location: varchar('location', { length: 100 }).notNull(),
  country: varchar('country', { length: 3 }), // ISO country code
  circuitName: varchar('circuit_name', { length: 100 }),
  fp1Date: timestamp('fp1_date'),        // Sexta - TL1 (trava lock_type='fp1')
  qualifyingDate: timestamp('qualifying_date'), // Sabado - Classificacao (trava lock_type='qualifying')
  raceDate: timestamp('race_date').notNull(),   // Domingo - Corrida (trava lock_type='race')
  sprintQualifyingDate: timestamp('sprint_qualifying_date'), // Classificacao Sprint (fins de semana sprint)
  sprintDate: timestamp('sprint_date'),                       // Corrida Sprint
  isSprintWeekend: boolean('is_sprint_weekend').default(false),
  season: integer('season').notNull(), // 2026, etc
  round: integer('round').notNull(),   // Numero da corrida na temporada
  isCompleted: boolean('is_completed').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
}, (table) => ({
  seasonRoundUnique: unique().on(table.season, table.round),
}));

module.exports = { races };
