const { pgTable, serial, varchar, text, integer, boolean, timestamp } = require('drizzle-orm/pg-core');
const { teams } = require('./teams');

// Tabela de pilotos (ex: Max Verstappen, Lewis Hamilton)
const drivers = pgTable('drivers', {
  id: serial('id').primaryKey(),
  teamId: integer('team_id').references(() => teams.id, { onDelete: 'set null' }),
  firstName: varchar('first_name', { length: 50 }).notNull(),
  lastName: varchar('last_name', { length: 50 }).notNull(),
  number: integer('number'),
  photoUrl: text('photo_url'),
  nationality: varchar('nationality', { length: 3 }), // ISO country code (BRA, GBR, etc)
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { drivers };
