const { Router } = require('express');
const {
  getMyLeagues, getPublicLeagues, getLeague,
  createLeague, updateLeague, deleteLeague,
  joinLeague, joinByCode, inviteMember,
  getMembers, removeMember,
  getPendingRequests, approveRequest, rejectRequest,
  getPublicLeaguesForPrediction,
  getLeagueRacesStatus,
} = require('../controllers/leagues.controller');
const {
  getLeagueMessages,
  updateLeagueChatSettings,
  addChatAllowed,
  removeChatAllowed,
} = require('../controllers/messages.controller');
const {
  getPosts,
  createPost,
  deletePost,
  toggleLike,
  getComments,
  addComment,
  deleteComment,
  votePoll,
  updatePostSettings,
  getHighlights,
  getPredictionsRevealed,
} = require('../controllers/leaguePosts.controller');
const { authenticate, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validator');
const { createLeagueSchema, updateLeagueSchema, inviteSchema } = require('../utils/validators');

const router = Router();

// Rotas públicas
router.get('/public', optionalAuth, getPublicLeagues);

// Rotas autenticadas
router.get('/', authenticate, getMyLeagues);
router.post('/', authenticate, validate(createLeagueSchema), createLeague);
router.post('/join-by-code', authenticate, joinByCode);
// Deve vir antes de /:id para não ser capturado como parâmetro dinâmico
router.get('/public-for-prediction', authenticate, getPublicLeaguesForPrediction);
router.get('/:id', authenticate, getLeague);
router.put('/:id', authenticate, validate(updateLeagueSchema), updateLeague);
router.delete('/:id', authenticate, deleteLeague);
router.post('/:id/join', authenticate, joinLeague);
router.post('/:id/invite', authenticate, validate(inviteSchema), inviteMember);
router.get('/:id/members', authenticate, getMembers);
router.delete('/:id/members/:userId', authenticate, removeMember);

// Corridas da liga com status de palpite do usuário
router.get('/:id/races-status', authenticate, getLeagueRacesStatus);

// Solicitações de entrada (ligas privadas)
router.get('/:id/requests', authenticate, getPendingRequests);
router.post('/:id/requests/:userId/approve', authenticate, approveRequest);
router.delete('/:id/requests/:userId', authenticate, rejectRequest);

// Chat da liga
router.get('/:id/messages', authenticate, getLeagueMessages);
router.put('/:id/chat-settings', authenticate, updateLeagueChatSettings);
router.post('/:id/chat-allowed/:userId', authenticate, addChatAllowed);
router.delete('/:id/chat-allowed/:userId', authenticate, removeChatAllowed);

// Mural da liga (posts, curtidas, comentários, enquetes)
router.get('/:id/highlights', authenticate, getHighlights);
router.get('/:id/predictions-revealed/:raceId', authenticate, getPredictionsRevealed);
router.put('/:id/post-settings', authenticate, updatePostSettings);
router.get('/:id/posts', authenticate, getPosts);
router.post('/:id/posts', authenticate, createPost);
router.delete('/:id/posts/:postId', authenticate, deletePost);
router.post('/:id/posts/:postId/like', authenticate, toggleLike);
router.get('/:id/posts/:postId/comments', authenticate, getComments);
router.post('/:id/posts/:postId/comments', authenticate, addComment);
router.delete('/:id/posts/:postId/comments/:commentId', authenticate, deleteComment);
router.post('/:id/polls/:pollId/vote', authenticate, votePoll);

module.exports = router;
