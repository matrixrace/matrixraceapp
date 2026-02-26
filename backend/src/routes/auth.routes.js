const { Router } = require('express');
const { register, getMe, updateProfile } = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validator');
const { registerSchema } = require('../utils/validators');

const router = Router();

// Rota pública: registrar novo usuário
router.post('/register', validate(registerSchema), register);

// Rotas autenticadas
router.get('/me', authenticate, getMe);
router.put('/me', authenticate, updateProfile);

module.exports = router;
