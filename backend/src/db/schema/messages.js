const { pgTable, uuid, text, boolean, timestamp } = require('drizzle-orm/pg-core');
const { users } = require('./users');
const { leagues } = require('./leagues');

// Tabela de mensagens
// Cada registro = uma mensagem enviada
// Se receiverId está preenchido = chat privado entre amigos
// Se leagueId está preenchido = chat em grupo de uma liga
const messages = pgTable('messages', {
  id: uuid('id').defaultRandom().primaryKey(),
  senderId: uuid('sender_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  receiverId: uuid('receiver_id').references(() => users.id, { onDelete: 'cascade' }),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }),
  content: text('content').notNull(),
  isRead: boolean('is_read').default(false),
  createdAt: timestamp('created_at').defaultNow(),
});

module.exports = { messages };
