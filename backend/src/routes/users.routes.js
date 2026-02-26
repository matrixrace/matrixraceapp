const { Router } = require('express');
const { searchUsers, getUserProfile } = require('../controllers/users.controller');
const { authenticate } = require('../middleware/auth');

const router = Router();

// Todas as rotas exigem autenticação
router.use(authenticate);

// Busca usuários por nome
router.get('/search', searchUsers);

// Ver perfil público de um usuário
router.get('/:id', getUserProfile);

module.exports = router;
