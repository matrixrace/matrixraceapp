// Exporta todas as tabelas do banco de dados
// Este arquivo centraliza todos os schemas para uso no Drizzle ORM

const { users } = require('./users');
const { teams } = require('./teams');
const { drivers } = require('./drivers');
const { races } = require('./races');
const { raceResults } = require('./raceResults');
const { leagues } = require('./leagues');
const { leagueRaces } = require('./leagueRaces');
const { leagueMembers } = require('./leagueMembers');
const { predictions } = require('./predictions');
const { predictionApplications } = require('./predictionApplications');
const { scores } = require('./scores');
const { invitations } = require('./invitations');
const { friendships } = require('./friendships');
const { messages } = require('./messages');
const { notifications } = require('./notifications');
const { leagueChatAllowed } = require('./leagueChatAllowed');
const { leaguePosts } = require('./leaguePosts');
const { leaguePostLikes } = require('./leaguePostLikes');
const { leaguePostComments } = require('./leaguePostComments');
const { leaguePolls } = require('./leaguePolls');
const { leaguePollOptions } = require('./leaguePollOptions');
const { leaguePollVotes } = require('./leaguePollVotes');

module.exports = {
  users,
  teams,
  drivers,
  races,
  raceResults,
  leagues,
  leagueRaces,
  leagueMembers,
  predictions,
  predictionApplications,
  scores,
  invitations,
  friendships,
  messages,
  notifications,
  leagueChatAllowed,
  leaguePosts,
  leaguePostLikes,
  leaguePostComments,
  leaguePolls,
  leaguePollOptions,
  leaguePollVotes,
};
