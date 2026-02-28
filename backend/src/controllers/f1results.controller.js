const { fetchJolpica } = require('../utils/jolpica');
const { successResponse } = require('../utils/helpers');

// GET /api/v1/f1-results?year=2025
// Proxy para a Jolpica API, retorna resultados de todas as corridas do ano
async function getF1Results(req, res, next) {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    if (year < 1950 || year > new Date().getFullYear()) {
      return res.status(400).json({ success: false, message: 'Ano inválido' });
    }

    const allRaces = await fetchAllPages(year);

    const races = allRaces.map((race) => ({
      round: race.round,
      raceName: race.raceName,
      date: race.date,
      circuit: race.Circuit?.circuitName || '',
      locality: race.Circuit?.Location?.locality || '',
      country: race.Circuit?.Location?.country || '',
      results: (race.Results || []).map((r) => ({
        position: r.position,
        driver: `${r.Driver?.givenName} ${r.Driver?.familyName}`,
        driverCode: r.Driver?.code || '',
        team: r.Constructor?.name || '',
        grid: r.grid,
        laps: r.laps,
        status: r.status,
        time: r.Time?.time || null,
        points: r.points,
      })),
    }));

    res.json(successResponse({ season: String(year), races }));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/f1-results/drivers?year=2025
// Retorna a classificação de pilotos do campeonato no ano
async function getDriverStandings(req, res, next) {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    if (year < 1950 || year > new Date().getFullYear()) {
      return res.status(400).json({ success: false, message: 'Ano inválido' });
    }

    const data = await fetchJolpica(`https://api.jolpi.ca/ergast/f1/${year}/driverStandings.json`);
    const list = data.MRData?.StandingsTable?.StandingsLists?.[0];

    const season = list?.season || String(year);
    const round = list?.round || '';
    const standings = (list?.DriverStandings || []).map((s) => ({
      position: s.position,
      points: s.points,
      wins: s.wins,
      driver: `${s.Driver?.givenName} ${s.Driver?.familyName}`,
      driverCode: s.Driver?.code || '',
      nationality: s.Driver?.nationality || '',
      team: s.Constructors?.[0]?.name || '',
    }));

    res.json(successResponse({ season, round, standings }));
  } catch (error) {
    next(error);
  }
}

// GET /api/v1/f1-results/constructors?year=2025
// Retorna a classificação de construtores do campeonato no ano
async function getConstructorStandings(req, res, next) {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();

    if (year < 1950 || year > new Date().getFullYear()) {
      return res.status(400).json({ success: false, message: 'Ano inválido' });
    }

    const data = await fetchJolpica(`https://api.jolpi.ca/ergast/f1/${year}/constructorStandings.json`);
    const list = data.MRData?.StandingsTable?.StandingsLists?.[0];

    const season = list?.season || String(year);
    const round = list?.round || '';
    const standings = (list?.ConstructorStandings || []).map((s) => ({
      position: s.position,
      points: s.points,
      wins: s.wins,
      team: s.Constructor?.name || '',
      nationality: s.Constructor?.nationality || '',
    }));

    res.json(successResponse({ season, round, standings }));
  } catch (error) {
    next(error);
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

// Busca todas as páginas da Jolpica e mescla as corridas corretamente
async function fetchAllPages(year) {
  const limit = 100;
  let offset = 0;
  let total = null;
  const racesMap = new Map(); // round → race com Results acumulados

  do {
    const data = await fetchJolpica(
      `https://api.jolpi.ca/ergast/f1/${year}/results.json?limit=${limit}&offset=${offset}`
    );
    const mrData = data.MRData;

    if (total === null) total = parseInt(mrData.total) || 0;

    const races = mrData.RaceTable?.Races || [];
    for (const race of races) {
      if (!racesMap.has(race.round)) {
        racesMap.set(race.round, { ...race, Results: [] });
      }
      racesMap.get(race.round).Results.push(...(race.Results || []));
    }

    offset += limit;
  } while (offset < total);

  return Array.from(racesMap.values()).sort((a, b) => parseInt(a.round) - parseInt(b.round));
}

module.exports = { getF1Results, getDriverStandings, getConstructorStandings };
