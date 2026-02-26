const winston = require('winston');

// Configuração do logger
// Mostra mensagens no console com cores e timestamp
const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    // Console: sempre mostra mensagens
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, ...rest }) => {
          const extra = Object.keys(rest).length ? JSON.stringify(rest) : '';
          return `${timestamp} [${level}]: ${message} ${extra}`;
        })
      ),
    }),
  ],
});

module.exports = logger;
