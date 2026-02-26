const { pgTable, uuid, varchar, timestamp, unique } = require('drizzle-orm/pg-core');
const { users } = require('./users');

// Tabela de amizades
// Cada registro = um pedido de amizade ou amizade ativa entre dois usuários
const friendships = pgTable('friendships', {
  id: uuid('id').defaultRandom().primaryKey(),
  requesterId: uuid('requester_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  addresseeId: uuid('addressee_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  status: varchar('status', { length: 20 }).default('pending'), // pending | accepted | blocked
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
}, (table) => ({
  requesterAddresseeUnique: unique().on(table.requesterId, table.addresseeId),
}));

module.exports = { friendships };
