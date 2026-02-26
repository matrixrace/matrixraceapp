const { z } = require('zod');

// ============================
// SCHEMAS DE VALIDAÇÃO COM ZOD
// ============================
// Cada schema define quais campos são obrigatórios e seus tipos

// --- Auth ---
const registerSchema = z.object({
  firebaseUid: z.string().min(1, 'Firebase UID é obrigatório'),
  email: z.string().email('Email inválido'),
  displayName: z.string().min(2, 'Nome deve ter pelo menos 2 caracteres').max(100).optional(),
});

// --- Teams (Admin) ---
const createTeamSchema = z.object({
  name: z.string().min(2, 'Nome da equipe é obrigatório').max(100),
  colorPrimary: z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Cor deve ser hexadecimal (#FF0000)').optional(),
  colorSecondary: z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Cor deve ser hexadecimal').optional(),
});

const updateTeamSchema = createTeamSchema.partial();

// --- Drivers (Admin) ---
const createDriverSchema = z.object({
  teamId: z.number().int().positive('ID da equipe inválido').optional().nullable(),
  firstName: z.string().min(1, 'Primeiro nome é obrigatório').max(50),
  lastName: z.string().min(1, 'Sobrenome é obrigatório').max(50),
  number: z.number().int().min(0).max(99).optional().nullable(),
  nationality: z.string().length(3, 'Nacionalidade deve ter 3 letras (ISO)').optional(),
  isActive: z.boolean().optional(),
});

const updateDriverSchema = createDriverSchema.partial();

// --- Races (Admin) ---
const createRaceSchema = z.object({
  name: z.string().min(1, 'Nome da corrida é obrigatório').max(100),
  location: z.string().min(1, 'Local é obrigatório').max(100),
  country: z.string().length(3, 'País deve ter 3 letras (ISO)').optional(),
  circuitName: z.string().max(100).optional(),
  raceDate: z.string().refine((val) => !isNaN(Date.parse(val)), 'Data inválida'),
  season: z.number().int().min(2024).max(2100),
  round: z.number().int().min(1).max(50),
});

const updateRaceSchema = createRaceSchema.partial();

// --- Race Results (Admin) ---
const createRaceResultsSchema = z.object({
  results: z.array(
    z.object({
      driverId: z.number().int().positive('ID do piloto inválido'),
      position: z.number().int().min(1, 'Posição deve ser >= 1'),
    })
  ).min(1, 'Pelo menos 1 resultado é necessário'),
});

// --- Leagues ---
const createLeagueSchema = z.object({
  name: z.string().min(3, 'Nome deve ter pelo menos 3 caracteres').max(100),
  description: z.string().max(500).optional(),
  isPublic: z.boolean().default(false),
  requiresApproval: z.boolean().default(false),
  maxMembers: z.number().int().min(2).max(1000).optional(),
  raceIds: z.array(z.number().int().positive()).min(1, 'Selecione pelo menos 1 corrida'),
});

const updateLeagueSchema = z.object({
  name: z.string().min(3).max(100).optional(),
  description: z.string().max(500).optional(),
  isPublic: z.boolean().optional(),
  requiresApproval: z.boolean().optional(),
  maxMembers: z.number().int().min(2).max(1000).optional(),
});

// --- Predictions ---
const createPredictionSchema = z.object({
  leagueId: z.string().uuid('ID da liga inválido'),
  raceId: z.number().int().positive('ID da corrida inválido'),
  predictions: z.array(
    z.object({
      driverId: z.number().int().positive('ID do piloto inválido'),
      predictedPosition: z.number().int().min(1, 'Posição deve ser >= 1'),
    })
  ).min(1, 'Envie pelo menos 1 palpite'),
});

// --- Official Leagues (Admin) ---
const createOfficialLeagueSchema = z.object({
  name: z.string().min(3, 'Nome deve ter pelo menos 3 caracteres').max(100),
  description: z.string().max(500).optional(),
  raceId: z.number().int().positive('ID da corrida inválido'),
});

const updateOfficialLeagueSchema = z.object({
  name: z.string().min(3).max(100).optional(),
  description: z.string().max(500).optional(),
});

// --- Invite ---
const inviteSchema = z.object({
  email: z.string().email('Email inválido'),
});

module.exports = {
  registerSchema,
  createTeamSchema,
  updateTeamSchema,
  createDriverSchema,
  updateDriverSchema,
  createRaceSchema,
  updateRaceSchema,
  createRaceResultsSchema,
  createLeagueSchema,
  updateLeagueSchema,
  createPredictionSchema,
  createOfficialLeagueSchema,
  updateOfficialLeagueSchema,
  inviteSchema,
};
