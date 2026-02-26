const { pgTable, uuid, varchar, text, boolean, timestamp } = require('drizzle-orm/pg-core');
const { leagues } = require('./leagues');
const { users } = require('./users');

const leaguePosts = pgTable('league_posts', {
  id: uuid('id').defaultRandom().primaryKey(),
  leagueId: uuid('league_id').references(() => leagues.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  type: varchar('type', { length: 20 }).default('text').notNull(), // 'text' | 'poll'
  content: text('content'),
  isPinned: boolean('is_pinned').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});

module.exports = { leaguePosts };
