const dotenv = require('dotenv');
const path = require('path');

// Carrega variáveis de ambiente do arquivo .env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const config = {
  // Ambiente (development, production)
  nodeEnv: process.env.NODE_ENV || 'development',

  // Servidor
  port: parseInt(process.env.PORT, 10) || 3000,

  // Banco de dados
  databaseUrl: process.env.DATABASE_URL,

  // Firebase
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  },

  // Cloudinary (imagens)
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
  },

  // Email (Gmail)
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },

  // Frontend URL (para CORS)
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:8080',
};

module.exports = config;
