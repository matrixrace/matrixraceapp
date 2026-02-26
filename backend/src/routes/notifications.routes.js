const { Router } = require('express');
const { getNotifications, markAsRead, markAllAsRead } = require('../controllers/notifications.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// Lista notificações do usuário
router.get('/', getNotifications);

// Marca todas como lidas (deve vir antes de /:id para não conflitar)
router.put('/read-all', markAllAsRead);

// Marca uma notificação como lida
router.put('/:id/read', markAsRead);

module.exports = router;
