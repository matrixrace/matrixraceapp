const { pgTable, uuid, varchar, timestamp, unique } = require('drizzle-orm/pg-core');
const { chatGroups } = require('./chatGroups');
const { users } = require('./users');

// Tabela de membros de grupos de chat
// Cada registro = um usuário que pertence a um grupo
const chatGroupMembers = pgTable('chat_group_members', {
  id: uuid('id').defaultRandom().primaryKey(),
  groupId: uuid('group_id').references(() => chatGroups.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  role: varchar('role', { length: 20 }).default('member'), // admin | member
  joinedAt: timestamp('joined_at').defaultNow(),
}, (table) => ({
  groupUserUnique: unique().on(table.groupId, table.userId),
}));

module.exports = { chatGroupMembers };
