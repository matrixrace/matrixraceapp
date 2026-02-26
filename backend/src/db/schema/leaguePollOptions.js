const { pgTable, serial, uuid, varchar, integer } = require('drizzle-orm/pg-core');
const { leaguePolls } = require('./leaguePolls');

const leaguePollOptions = pgTable('league_poll_options', {
  id: serial('id').primaryKey(),
  pollId: uuid('poll_id').references(() => leaguePolls.id, { onDelete: 'cascade' }).notNull(),
  text: varchar('text', { length: 200 }).notNull(),
  orderIndex: integer('order_index').notNull(),
});

module.exports = { leaguePollOptions };
