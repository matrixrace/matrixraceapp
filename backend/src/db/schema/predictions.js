const { pgTable, uuid, integer, varchar, timestamp, unique } = require('drizzle-orm/pg-core');
const { races } = require('./races');
const { users } = require('./users');
const { drivers } = require('./drivers');

// Tabela de palpites
// Um palpite por usuário por corrida, independente de liga
// lock_type define quando o palpite foi travado (fp1/qualifying/race)
// max_points_per_driver define a pontuação máxima por piloto acertado
const predictions = pgTable('predictions', {
  id: uuid('id').defaultRandom().primaryKey(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  driverId: integer('driver_id').references(() => drivers.id, { onDelete: 'cascade' }).notNull(),
  predictedPosition: integer('predicted_position').notNull(),
  lockType: varchar('lock_type', { length: 20 }).notNull().default('race'), // 'fp1', 'qualifying', 'race'
  maxPointsPerDriver: integer('max_points_per_driver').notNull().default(10), // 20, 15 ou 10
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
}, (table) => ({
  // Mesmo usuário não pode prever mesma posição duas vezes na mesma corrida
  uniquePosition: unique().on(table.raceId, table.userId, table.predictedPosition),
  // Mesmo usuário não pode prever mesmo piloto duas vezes na mesma corrida
  uniqueDriver: unique().on(table.raceId, table.userId, table.driverId),
}));

module.exports = { predictions };
