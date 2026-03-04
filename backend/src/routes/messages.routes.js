const { Router } = require('express');
const {
  getConversations,
  getPrivateMessages,
  markAsRead,
} = require('../controllers/messages.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// Lista todas as conversas (última mensagem de cada) — inclui privadas e grupos
router.get('/conversations', getConversations);

// Marca mensagens como lidas
router.put('/read', markAsRead);

// Histórico de mensagens privadas com um amigo
router.get('/private/:friendId', getPrivateMessages);

module.exports = router;
