const { auth } = require('../config/firebase');
const { db } = require('../config/database');
const { users } = require('../db/schema');
const { eq } = require('drizzle-orm');
const logger = require('../utils/logger');

// Middleware de autenticação
// Verifica se o usuário enviou um token Firebase válido
// Se sim, busca o usuário no banco e coloca em req.user
async function authenticate(req, res, next) {
  try {
    // Pega o token do header Authorization
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Token de autenticação não fornecido',
      });
    }

    const token = authHeader.split('Bearer ')[1];

    // Verifica o token com Firebase
    const decodedToken = await auth.verifyIdToken(token);

    // Busca o usuário no banco de dados
    const [user] = await db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, decodedToken.uid))
      .limit(1);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Usuário não encontrado no sistema',
      });
    }

    // Coloca o usuário na requisição para uso nos controllers
    req.user = user;
    next();
  } catch (error) {
    logger.error('Erro na autenticação:', error.message);

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        message: 'Token expirado. Faça login novamente.',
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Token inválido',
    });
  }
}

// Middleware OPCIONAL de autenticação
// Se o token existir, busca o usuário. Se não existir, continua sem usuário.
// Útil para rotas que funcionam com ou sem login (ex: tela inicial)
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      req.user = null;
      return next();
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await auth.verifyIdToken(token);

    const [user] = await db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, decodedToken.uid))
      .limit(1);

    req.user = user || null;
    next();
  } catch (error) {
    req.user = null;
    next();
  }
}

module.exports = { authenticate, optionalAuth };
