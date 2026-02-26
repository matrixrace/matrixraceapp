const admin = require('firebase-admin');
const config = require('./environment');
const logger = require('../utils/logger');

// Inicializa o Firebase Admin SDK
// Isso permite verificar tokens de autenticação vindos do Flutter
let firebaseApp;

try {
  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: config.firebase.projectId,
      clientEmail: config.firebase.clientEmail,
      privateKey: config.firebase.privateKey,
    }),
  });
  logger.info('Firebase Admin inicializado com sucesso');
} catch (error) {
  logger.error('Erro ao inicializar Firebase Admin:', error.message);
  logger.warn('A autenticação Firebase não vai funcionar sem configuração correta');
}

// Exporta o serviço de autenticação
const auth = admin.auth();

module.exports = { auth, firebaseApp };
