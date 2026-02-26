const { db } = require('../config/database');
const { users } = require('../db/schema');
const { eq } = require('drizzle-orm');
const { successResponse } = require('../utils/helpers');
const { sendWelcomeEmail } = require('../services/email.service');
const logger = require('../utils/logger');

// POST /api/v1/auth/register
// Registra um novo usuário no banco de dados (após criar conta no Firebase)
async function register(req, res, next) {
  try {
    const { firebaseUid, email, displayName, country, state, city } = req.body;

    // Verifica se já existe
    const [existing] = await db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, firebaseUid))
      .limit(1);

    if (existing) {
      return res.json(successResponse(existing, 'Usuário já existe'));
    }

    // Cria o usuário
    const [newUser] = await db
      .insert(users)
      .values({ firebaseUid, email, displayName, country, state, city })
      .returning();

    logger.info(`Novo usuário registrado: ${email}`);

    // Envia email de boas-vindas (não bloqueia se falhar)
    sendWelcomeEmail({ to: email, displayName }).catch(() => {});

    res.status(201).json(successResponse(newUser, 'Usuário registrado com sucesso'));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/auth/me
// Retorna os dados do usuário logado
async function getMe(req, res) {
  res.json(successResponse(req.user));
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

module.exports = { register, getMe, updateProfile };
