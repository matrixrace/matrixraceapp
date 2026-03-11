const { db } = require('../config/database');
const { users } = require('../db/schema');
const { eq } = require('drizzle-orm');
const { successResponse, errorResponse } = require('../utils/helpers');
const { sendWelcomeEmail } = require('../services/email.service');
const { uploadImage } = require('../services/storage.service');
const { getPodiumStats } = require('../services/scoring.service');
const logger = require('../utils/logger');

// POST /api/v1/auth/register
// Registra um novo usuário no banco de dados (após criar conta no Firebase)
// Aceita photoUrl opcional (usado no login com Google)
async function register(req, res, next) {
  try {
    const { firebaseUid, email, displayName, country, state, city, photoUrl } = req.body;

    // Verifica se já existe
    const [existing] = await db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, firebaseUid))
      .limit(1);

    if (existing) {
      // Atualiza avatarUrl se chegou foto do Google e o usuário ainda não tem
      if (photoUrl && !existing.avatarUrl) {
        const [updated] = await db
          .update(users)
          .set({ avatarUrl: photoUrl, updatedAt: new Date() })
          .where(eq(users.firebaseUid, firebaseUid))
          .returning();
        return res.json(successResponse(updated, 'Usuário já existe'));
      }
      return res.json(successResponse(existing, 'Usuário já existe'));
    }

    // Cria o usuário
    const [newUser] = await db
      .insert(users)
      .values({ firebaseUid, email, displayName, country, state, city, avatarUrl: photoUrl || null })
      .returning();

    logger.info(`Novo usuário registrado: ${email}`);

    // Envia email de boas-vindas (não bloqueia se falhar)
    sendWelcomeEmail({ to: email, displayName }).catch(() => {});

    res.status(201).json(successResponse(newUser, 'Usuário registrado com sucesso'));
  } catch (error) {
    next(error);
  }
}

// POST /api/v1/auth/me/avatar
// Faz upload da foto de perfil para o Cloudinary e salva a URL no banco
async function uploadAvatar(req, res, next) {
  try {
    if (!req.file) {
      return next(errorResponse('Nenhuma imagem enviada', 400));
    }

    const { url } = await uploadImage(req.file.buffer, 'avatars', {
      width: 300,
      height: 300,
      mimeType: req.file.mimetype,
    });

    const [updated] = await db
      .update(users)
      .set({ avatarUrl: url, updatedAt: new Date() })
      .where(eq(users.id, req.user.id))
      .returning();

    res.json(successResponse({ avatarUrl: url }, 'Foto de perfil atualizada'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/auth/me
// Retorna os dados do usuário logado
async function getMe(req, res, next) {
  try {
    const podium = await getPodiumStats([req.user.id]);
    const data = {
      ...req.user,
      podiumStats: podium[req.user.id] || { gold: 0, silver: 0, bronze: 0 },
    };
    res.json(successResponse(data));
  } catch (error) {
    next(error);
  }
}

// PUT /api/v1/auth/me
// Atualiza o perfil do usuário logado
async function updateProfile(req, res, next) {
  try {
    const { displayName, bio, country, state, city } = req.body;

    const updateData = { updatedAt: new Date() };
    if (displayName !== undefined) updateData.displayName = displayName;
    if (bio !== undefined) updateData.bio = bio;
    if (country !== undefined) updateData.country = country;
    if (state !== undefined) updateData.state = state;
    if (city !== undefined) updateData.city = city;

    const [updated] = await db
      .update(users)
      .set(updateData)
      .where(eq(users.id, req.user.id))
      .returning();

    res.json(successResponse(updated, 'Perfil atualizado'));
  } catch (error) {
    next(error);
  }
}

module.exports = { register, getMe, updateProfile, uploadAvatar };
