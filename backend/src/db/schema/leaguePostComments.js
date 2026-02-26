const { pgTable, uuid, text, timestamp } = require('drizzle-orm/pg-core');
const { leaguePosts } = require('./leaguePosts');
const { users } = require('./users');

const leaguePostComments = pgTable('league_post_comments', {
  id: uuid('id').defaultRandom().primaryKey(),
  postId: uuid('post_id').references(() => leaguePosts.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  content: text('content').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
});

module.exports = { leaguePostComments };
