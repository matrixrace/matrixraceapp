const crypto = require('crypto');
const config = require('../config/environment');

function authenticateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];

  if (!config.liveApiKey) {
    return res.status(500).json({ success: false, message: 'API key nao configurada no servidor' });
  }

  if (!apiKey) {
    return res.status(401).json({ success: false, message: 'Header X-API-Key ausente' });
  }

  // Comparacao segura contra timing attacks
  const keyBuffer = Buffer.from(config.liveApiKey, 'utf8');
  const providedBuffer = Buffer.from(apiKey, 'utf8');

  if (keyBuffer.length !== providedBuffer.length || !crypto.timingSafeEqual(keyBuffer, providedBuffer)) {
    return res.status(401).json({ success: false, message: 'API key invalida' });
  }

  req.apiKeyAuth = true;
  next();
}

module.exports = { authenticateApiKey };
