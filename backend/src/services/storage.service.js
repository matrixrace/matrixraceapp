const cloudinary = require('../config/cloudinary');
const logger = require('../utils/logger');

// Faz upload de uma imagem para o Cloudinary
// Recebe o buffer do arquivo (da memória) e a pasta de destino
async function uploadImage(fileBuffer, folder, options = {}) {
  try {
    // Converte o buffer para base64 para enviar ao Cloudinary
    const base64 = fileBuffer.toString('base64');
    const dataUri = `data:image/png;base64,${base64}`;

    const result = await cloudinary.uploader.upload(dataUri, {
      folder: `f1-predictions/${folder}`,
      transformation: [
        { width: options.width || 400, height: options.height || 400, crop: 'limit' },
        { quality: 'auto', fetch_format: 'auto' },
      ],
    });

    logger.info(`Imagem enviada: ${result.public_id}`);

    return {
      url: result.secure_url,
      publicId: result.public_id,
    };
  } catch (error) {
    logger.error('Erro ao enviar imagem:', error.message);
    throw new Error('Falha ao enviar imagem');
  }
}

// Deleta uma imagem do Cloudinary
async function deleteImage(publicId) {
  try {
    await cloudinary.uploader.destroy(publicId);
    logger.info(`Imagem deletada: ${publicId}`);
    return true;
  } catch (error) {
    logger.error('Erro ao deletar imagem:', error.message);
    return false;
  }
}

module.exports = { uploadImage, deleteImage };
