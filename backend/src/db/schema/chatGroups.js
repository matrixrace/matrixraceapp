const { pgTable, uuid, varchar, text, timestamp } = require('drizzle-orm/pg-core');
const { users } = require('./users');

// Tabela de grupos de chat
// Grupos criados por usuários para conversar com amigos (separado de ligas)
const chatGroups = pgTable('chat_groups', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: varchar('name', { length: 100 }).notNull(),
  avatarUrl: text('avatar_url'),
  creatorId: uuid('creator_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { chatGroups };
