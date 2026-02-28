const http = require('http');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const config = require('./config/environment');
const logger = require('./utils/logger');
const { testConnection } = require('./config/database');
const { errorHandler, notFound } = require('./middleware/errorHandler');
const { initSocket } = require('./config/socket');

// Importa as rotas
const authRoutes = require('./routes/auth.routes');
const racesRoutes = require('./routes/races.routes');
const leaguesRoutes = require('./routes/leagues.routes');
const predictionsRoutes = require('./routes/predictions.routes');
const rankingsRoutes = require('./routes/rankings.routes');
const adminRoutes = require('./routes/admin.routes');
const usersRoutes = require('./routes/users.routes');
const friendsRoutes = require('./routes/friends.routes');
const messagesRoutes = require('./routes/messages.routes');
const notificationsRoutes = require('./routes/notifications.routes');
const f1ResultsRoutes = require('./routes/f1results.routes');

// Cria o app Express e o servidor HTTP (necessário para Socket.io)
const app = express();
const httpServer = http.createServer(app);

// ==================
// MIDDLEWARES GLOBAIS
// ==================

// Segurança: adiciona headers de segurança
// CSP desabilitado pois o Flutter Web carrega recursos de CDNs externas (fonts, canvaskit)
app.use(helmet({
  contentSecurityPolicy: false,
}));

// CORS: permite requisições do frontend
app.use(cors({
  origin: config.frontendUrl,
  credentials: true,
}));

// Parse JSON no body das requisições
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting: limita requisições para evitar abuso
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 200, // máximo 200 requisições por janela
  message: {
    success: false,
    message: 'Muitas requisições. Tente novamente em 15 minutos.',
  },
});
app.use('/api/', limiter);

// Rate limiting mais restrito para auth
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  skipSuccessfulRequests: true,
  message: {
    success: false,
    message: 'Muitas tentativas. Tente novamente em 15 minutos.',
  },
});
app.use('/api/v1/auth/register', authLimiter);

// ==================
// ROTAS
// ==================

// Rota de saúde (health check)
app.get('/api/v1/health', (req, res) => {
  res.json({
    success: true,
    message: 'F1 Predictions API está rodando!',
    version: '1.0.0',
    environment: config.nodeEnv,
    timestamp: new Date().toISOString(),
  });
});

// Rotas da API
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/races', racesRoutes);
app.use('/api/v1/leagues', leaguesRoutes);
app.use('/api/v1/predictions', predictionsRoutes);
app.use('/api/v1/rankings', rankingsRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/users', usersRoutes);
app.use('/api/v1/friends', friendsRoutes);
app.use('/api/v1/messages', messagesRoutes);
app.use('/api/v1/notifications', notificationsRoutes);
app.use('/api/v1/f1-results', f1ResultsRoutes);

// ==================
// FRONTEND (Flutter Web)
// ==================

const publicPath = path.join(__dirname, '..', 'public');

// Service worker e index.html sem cache para sempre pegar versão atualizada
app.get('/flutter_service_worker.js', (req, res) => {
  res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.sendFile(path.join(publicPath, 'flutter_service_worker.js'));
});
app.get('/index.html', (req, res) => {
  res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Serve arquivos estáticos do Flutter
app.use(express.static(publicPath));

// Retorna o index.html para qualquer rota desconhecida (SPA)
app.get(/^\/(?!api).*/, (req, res) => {
  res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.sendFile(path.join(publicPath, 'index.html'));
});

// ==================
// TRATAMENTO DE ERROS
// ==================

// Rota não encontrada (404) - apenas para rotas /api
app.use(notFound);

// Handler global de erros
app.use(errorHandler);

// ==================
// INICIAR SERVIDOR
// ==================

async function start() {
  // Testa conexão com o banco de dados
  const dbConnected = await testConnection();

  if (!dbConnected) {
    logger.warn('Servidor iniciando SEM conexão com o banco de dados');
    logger.warn('Verifique a variável DATABASE_URL no arquivo .env');
  }

  // Inicializa Socket.io no servidor HTTP
  initSocket(httpServer, config.frontendUrl);

  httpServer.listen(config.port, () => {
    logger.info('========================================');
    logger.info(`  F1 Predictions API`);
    logger.info(`  Ambiente: ${config.nodeEnv}`);
    logger.info(`  Porta: ${config.port}`);
    logger.info(`  URL: http://localhost:${config.port}`);
    logger.info(`  Health: http://localhost:${config.port}/api/v1/health`);
    logger.info(`  Socket.io: ativo`);
    logger.info('========================================');
  });
}

start().catch((error) => {
  logger.error('Erro fatal ao iniciar servidor:', error);
  process.exit(1);
});

module.exports = app;
