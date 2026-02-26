const { pgTable, uuid, varchar, text, boolean, integer, decimal, timestamp } = require('drizzle-orm/pg-core');
const { users } = require('./users');

// Tabela de ligas
// Usuários criam ligas para competir com amigos
const leagues = pgTable('leagues', {
  id: uuid('id').defaultRandom().primaryKey(),
  name: varchar('name', { length: 100 }).notNull(),
  description: text('description'),
  ownerId: uuid('owner_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  isPublic: boolean('is_public').default(false),
  isOfficial: boolean('is_official').default(false),
  isPaid: boolean('is_paid').default(false),
  entryFee: decimal('entry_fee', { precision: 10, scale: 2 }).default('0'),
  inviteCode: varchar('invite_code', { length: 10 }).unique(),
  requiresApproval: boolean('requires_approval').default(false),
  maxMembers: integer('max_members'),
  chatMode: varchar('chat_mode', { length: 20 }).default('all'), // all | leader_only | selected
  postMode: varchar('post_mode', { length: 20 }).default('all'), // all | leader_only
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { leagues };
