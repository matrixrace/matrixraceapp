const { Router } = require('express');
const {
  getConversations,
  getPrivateMessages,
} = require('../controllers/messages.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// Lista todas as conversas (última mensagem de cada)
router.get('/conversations', getConversations);

// Histórico de mensagens privadas com um amigo
router.get('/private/:friendId', getPrivateMessages);

module.exports = router;
