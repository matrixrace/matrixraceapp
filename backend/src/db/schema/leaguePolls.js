const { pgTable, uuid, text, timestamp } = require('drizzle-orm/pg-core');
const { leaguePosts } = require('./leaguePosts');

const leaguePolls = pgTable('league_polls', {
  id: uuid('id').defaultRandom().primaryKey(),
  postId: uuid('post_id').references(() => leaguePosts.id, { onDelete: 'cascade' }).notNull(),
  question: text('question').notNull(),
  expiresAt: timestamp('expires_at'),
  createdAt: timestamp('created_at').defaultNow(),
});

module.exports = { leaguePolls };
