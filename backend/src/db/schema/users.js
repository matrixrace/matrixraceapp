const { pgTable, uuid, varchar, text, boolean, timestamp } = require('drizzle-orm/pg-core');

// Tabela de usuários
// Cada pessoa que se cadastra no app vira um registro aqui
const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  firebaseUid: varchar('firebase_uid', { length: 128 }).unique().notNull(),
  email: varchar('email', { length: 255 }).unique().notNull(),
  displayName: varchar('display_name', { length: 100 }),
  avatarUrl: text('avatar_url'),
  bio: text('bio'),
  country: varchar('country', { length: 100 }),
  state: varchar('state', { length: 100 }),
  city: varchar('city', { length: 100 }),
  isAdmin: boolean('is_admin').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { users };
