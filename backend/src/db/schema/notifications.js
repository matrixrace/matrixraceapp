const { pgTable, uuid, varchar, text, boolean, timestamp, json } = require('drizzle-orm/pg-core');
const { users } = require('./users');

// Tabela de notificações
// Cada registro = uma notificação para um usuário
// Tipos: friend_request | friend_accepted | new_message | league_message
const notifications = pgTable('notifications', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  type: varchar('type', { length: 50 }).notNull(),
  title: varchar('title', { length: 200 }).notNull(),
  body: text('body'),
  data: json('data'), // ex: { friendshipId, senderId, leagueId }
  isRead: boolean('is_read').default(false),
  createdAt: timestamp('created_at').defaultNow(),
});

module.exports = { notifications };
