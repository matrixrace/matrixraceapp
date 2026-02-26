const logger = require('../utils/logger');
const config = require('../config/environment');

// Middleware global de tratamento de erros
// Captura qualquer erro que aconteça nas rotas e retorna resposta amigável
function errorHandler(err, req, res, _next) {
  logger.error('Erro não tratado:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // Em desenvolvimento mostra detalhes do erro; em produção esconde
  const response = {
    success: false,
    message: config.nodeEnv === 'production'
      ? 'Erro interno do servidor'
      : err.message,
  };

  if (config.nodeEnv !== 'production') {
    response.stack = err.stack;
  }

  const statusCode = err.statusCode || 500;
  res.status(statusCode).json(response);
}

// Middleware para rotas não encontradas (404)
function notFound(req, res) {
  res.status(404).json({
    success: false,
    message: `Rota não encontrada: ${req.method} ${req.path}`,
  });
}

module.exports = { errorHandler, notFound };
