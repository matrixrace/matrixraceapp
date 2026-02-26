const { pgTable, serial, varchar, text, timestamp } = require('drizzle-orm/pg-core');

// Tabela de equipes (ex: Red Bull, Ferrari, Mercedes)
const teams = pgTable('teams', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 100 }).unique().notNull(),
  logoUrl: text('logo_url'),
  colorPrimary: varchar('color_primary', { length: 7 }), // Cor hex (#FF0000)
  colorSecondary: varchar('color_secondary', { length: 7 }),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { teams };
