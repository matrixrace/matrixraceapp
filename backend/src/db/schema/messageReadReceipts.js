const { pgTable, uuid, timestamp, unique } = require('drizzle-orm/pg-core');
const { messages } = require('./messages');
const { users } = require('./users');

// Tabela de confirmações de leitura de mensagens (para grupos)
// Em chats privados usamos messages.readAt; em grupos, cada membro tem seu receipt
const messageReadReceipts = pgTable('message_read_receipts', {
  id: uuid('id').defaultRandom().primaryKey(),
  messageId: uuid('message_id').references(() => messages.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  readAt: timestamp('read_at').defaultNow(),
}, (table) => ({
  messageUserUnique: unique().on(table.messageId, table.userId),
}));

module.exports = { messageReadReceipts };
