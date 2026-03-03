const multer = require('multer');

// Configuração do Multer para upload de imagens
// Armazena temporariamente em memória antes de enviar ao Cloudinary
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024, // Máximo 20MB por arquivo
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Apenas imagens são permitidas'));
    }
  },
});

module.exports = { upload };
