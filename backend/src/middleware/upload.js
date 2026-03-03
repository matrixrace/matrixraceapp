const multer = require('multer');

// Configuração do Multer para upload de imagens
// Armazena temporariamente em memória antes de enviar ao Cloudinary
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024, // Máximo 20MB por arquivo
  },
  fileFilter: (req, file, cb) => {
    // Só aceita imagens
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];

    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Tipo de arquivo não permitido. Use: JPEG, PNG, WebP ou SVG'));
    }
  },
});

module.exports = { upload };
