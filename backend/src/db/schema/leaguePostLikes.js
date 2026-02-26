const { pgTable, serial, uuid, timestamp, unique } = require('drizzle-orm/pg-core');
const { leaguePosts } = require('./leaguePosts');
const { users } = require('./users');

const leaguePostLikes = pgTable('league_post_likes', {
  id: serial('id').primaryKey(),
  postId: uuid('post_id').references(() => leaguePosts.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
}, (t) => [unique().on(t.postId, t.userId)]);

module.exports = { leaguePostLikes };
