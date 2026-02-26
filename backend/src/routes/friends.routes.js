const { Router } = require('express');
const {
  getFriends,
  getFriendRequests,
  sendFriendRequest,
  acceptFriendRequest,
  removeFriend,
} = require('../controllers/friends.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// Lista de amigos aceitos
router.get('/', getFriends);

// Pedidos de amizade recebidos pendentes
router.get('/requests', getFriendRequests);

// Enviar pedido de amizade
router.post('/request/:userId', sendFriendRequest);

// Aceitar pedido de amizade
router.put('/:friendshipId/accept', acceptFriendRequest);

// Recusar pedido ou desfazer amizade
router.delete('/:friendshipId', removeFriend);

module.exports = router;
