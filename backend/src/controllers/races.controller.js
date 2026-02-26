const { db, pool } = require('../config/database');
const { races, drivers, teams } = require('../db/schema');
const { eq, gt, asc } = require('drizzle-orm');
const { successResponse } = require('../utils/helpers');

// GET /api/v1/races/all
// Retorna todas as corridas (passadas e futuras) ordenadas por data
async function getAllRaces(req, res, next) {
  try {
    const all = await db
      .select()
      .from(races)
      .orderBy(asc(races.raceDate));
    res.json(successResponse(all));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/upcoming
// Retorna as próximas corridas (que ainda não aconteceram)
async function getUpcomingRaces(req, res, next) {
  try {
    const upcoming = await db
      .select()
      .from(races)
      .where(eq(races.isCompleted, false))
      .orderBy(asc(races.raceDate))
      .limit(24);

    res.json(successResponse(upcoming));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/:id
// Retorna detalhes de uma corrida específica
async function getRace(req, res, next) {
  try {
    const { id } = req.params;

    const [race] = await db
      .select()
      .from(races)
      .where(eq(races.id, parseInt(id)))
      .limit(1);

    if (!race) {
      return res.status(404).json({ success: false, message: 'Corrida não encontrada' });
    }

    res.json(successResponse(race));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/drivers
// Retorna lista de pilotos ativos (para fazer palpites)
async function getActiveDrivers(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT d.*, t.name as team_name, t.color_primary as team_color,
              t.logo_url as team_logo_url
       FROM drivers d
       LEFT JOIN teams t ON t.id = d.team_id
       WHERE d.is_active = true
       ORDER BY t.name, d.last_name`
    );

    res.json(successResponse(result.rows));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/races/:id/official-league
// Retorna a liga oficial vinculada a esta corrida (pública, sem precisar ser membro)
async function getOfficialLeagueForRace(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `SELECT l.id, l.name, l.description, l.invite_code, l.is_official,
              COUNT(DISTINCT lm.user_id) as member_count
       FROM leagues l
       JOIN league_races lr ON lr.league_id = l.id
       LEFT JOIN league_members lm ON lm.league_id = l.id
       WHERE lr.race_id = $1 AND l.is_official = true AND l.is_public = true
       GROUP BY l.id
       LIMIT 1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.json(successResponse(null, 'Nenhuma liga oficial para esta corrida'));
    }

    res.json(successResponse(result.rows[0]));
  } catch (error) {
    next(error);
  }
}

module.exports = { getAllRaces, getUpcomingRaces, getRace, getActiveDrivers, getOfficialLeagueForRace };
