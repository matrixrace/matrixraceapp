const { pgTable, serial, uuid, integer, timestamp, unique } = require('drizzle-orm/pg-core');
const { leaguePolls } = require('./leaguePolls');
const { leaguePollOptions } = require('./leaguePollOptions');
const { users } = require('./users');

const leaguePollVotes = pgTable('league_poll_votes', {
  id: serial('id').primaryKey(),
  pollId: uuid('poll_id').references(() => leaguePolls.id, { onDelete: 'cascade' }).notNull(),
  optionId: integer('option_id').references(() => leaguePollOptions.id, { onDelete: 'cascade' }).notNull(),
  userId: uuid('user_id').references(() => users.id, { onDelete: 'cascade' }).notNull(),
  createdAt: timestamp('created_at').defaultNow(),
}, (t) => [unique().on(t.pollId, t.userId)]);

module.exports = { leaguePollVotes };
