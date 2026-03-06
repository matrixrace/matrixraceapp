const { pgTable, serial, varchar, integer, text, timestamp } = require('drizzle-orm/pg-core');
const { races } = require('./races');

// Mensagens de direcao de prova (bandeiras, penalidades, safety car)
const raceControlMessages = pgTable('race_control_messages', {
  id: serial('id').primaryKey(),
  raceId: integer('race_id').references(() => races.id, { onDelete: 'cascade' }).notNull(),
  sessionType: varchar('session_type', { length: 30 }).notNull(),
  message: text('message').notNull(),
  flag: varchar('flag', { length: 20 }), // GREEN, YELLOW, RED, CHEQUERED, SAFETY_CAR, VSC
  driverNumber: integer('driver_number'),
  happenedAt: timestamp('happened_at').defaultNow(),
  createdAt: timestamp('created_at').defaultNow(),
});

module.exports = { raceControlMessages };
