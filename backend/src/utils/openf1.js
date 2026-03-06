const https = require('https');
const logger = require('./logger');

const BASE_URL = 'https://api.openf1.org/v1';

// Mapeamento session_type interno -> nome OpenF1
const SESSION_TYPE_MAP = {
  'FP1': 'Practice 1',
  'FP2': 'Practice 2',
  'FP3': 'Practice 3',
  'qualifying': 'Qualifying',
  'sprint_qualifying': 'Sprint Qualifying',
  'sprint': 'Sprint',
  'race': 'Race',
};

// Faz requisicao HTTPS para a OpenF1 API
function fetchOpenF1(path) {
  const url = `${BASE_URL}${path}`;
  logger.info(`OpenF1 request: ${url}`);

  return new Promise((resolve, reject) => {
    https.get(url, { timeout: 20000 }, (resp) => {
      let data = '';
      resp.on('data', (chunk) => { data += chunk; });
      resp.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve(parsed);
        } catch (e) {
          reject(new Error('Falha ao parsear resposta da OpenF1 API'));
        }
      });
    }).on('error', (err) => {
      reject(err);
    }).on('timeout', function () {
      this.destroy();
      reject(new Error('Timeout ao chamar OpenF1 API'));
    });
  });
}

// Busca o session_key para uma sessao especifica
async function getSessionKey(year, round, sessionType) {
  const sessionName = SESSION_TYPE_MAP[sessionType];
  if (!sessionName) throw new Error(`Tipo de sessao invalido: ${sessionType}`);

  // Primeiro busca o meeting (GP) pelo ano e round
  const meetings = await fetchOpenF1(`/meetings?year=${year}`);
  if (!Array.isArray(meetings) || meetings.length === 0) {
    throw new Error(`Nenhum meeting encontrado para ${year}`);
  }

  // Ordena meetings por data e pega o round correto (1-indexed)
  const sorted = meetings.sort((a, b) => new Date(a.date_start) - new Date(b.date_start));
  const meeting = sorted[round - 1];
  if (!meeting) {
    throw new Error(`Round ${round} nao encontrado em ${year}`);
  }

  // Busca sessoes desse meeting
  const sessions = await fetchOpenF1(`/sessions?meeting_key=${meeting.meeting_key}&session_name=${encodeURIComponent(sessionName)}`);
  if (!Array.isArray(sessions) || sessions.length === 0) {
    throw new Error(`Sessao ${sessionName} nao encontrada para ${meeting.meeting_name}`);
  }

  return sessions[0].session_key;
}

// Busca posicoes mais recentes de cada piloto na sessao
async function getPositions(sessionKey) {
  const data = await fetchOpenF1(`/position?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return [];

  // Agrupa por driver_number, pega a posicao mais recente
  const latest = {};
  for (const entry of data) {
    const dn = entry.driver_number;
    if (!latest[dn] || new Date(entry.date) > new Date(latest[dn].date)) {
      latest[dn] = entry;
    }
  }

  return Object.values(latest).sort((a, b) => a.position - b.position);
}

// Busca melhor volta de cada piloto
async function getBestLaps(sessionKey) {
  const data = await fetchOpenF1(`/laps?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return {};

  // Agrupa por driver_number, pega o menor lap_duration
  const best = {};
  for (const lap of data) {
    const dn = lap.driver_number;
    if (lap.lap_duration && (!best[dn] || lap.lap_duration < best[dn].lap_duration)) {
      best[dn] = lap;
    }
  }

  return best;
}

// Busca stints (pneus) de cada piloto
async function getStints(sessionKey) {
  const data = await fetchOpenF1(`/stints?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return {};

  // Agrupa por driver_number, pega o stint mais recente
  const latest = {};
  for (const stint of data) {
    const dn = stint.driver_number;
    if (!latest[dn] || stint.stint_number > latest[dn].stint_number) {
      latest[dn] = stint;
    }
  }

  return latest;
}

// Busca pit stops de cada piloto
async function getPitStops(sessionKey) {
  const data = await fetchOpenF1(`/pit?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return {};

  // Conta pit stops por driver_number
  const counts = {};
  for (const pit of data) {
    const dn = pit.driver_number;
    counts[dn] = (counts[dn] || 0) + 1;
  }

  return counts;
}

// Busca mensagens de direcao de prova
async function getRaceControlMessages(sessionKey) {
  const data = await fetchOpenF1(`/race_control?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return [];

  return data.map((msg) => ({
    message: msg.message || '',
    flag: msg.flag || null,
    driverNumber: msg.driver_number || null,
    happenedAt: msg.date || new Date().toISOString(),
  }));
}

// Formata duracao em segundos para "M:SS.mmm"
function formatLapTime(durationSeconds) {
  if (!durationSeconds) return null;
  const minutes = Math.floor(durationSeconds / 60);
  const seconds = (durationSeconds % 60).toFixed(3);
  return `${minutes}:${seconds.padStart(6, '0')}`;
}

// Busca todos os dados de uma sessao e retorna formatado
async function fetchSessionData(year, round, sessionType) {
  const sessionKey = await getSessionKey(year, round, sessionType);

  // Busca dados em paralelo
  const [positions, bestLaps, stints, pitStops, raceControl] = await Promise.all([
    getPositions(sessionKey),
    getBestLaps(sessionKey),
    getStints(sessionKey),
    getPitStops(sessionKey),
    getRaceControlMessages(sessionKey),
  ]);

  // Monta resultado final por piloto
  const results = positions.map((pos) => {
    const dn = pos.driver_number;
    const lap = bestLaps[dn];
    const stint = stints[dn];
    const pits = pitStops[dn] || 0;

    return {
      driverNumber: dn,
      position: pos.position,
      bestLapTime: lap ? formatLapTime(lap.lap_duration) : null,
      gap: null, // Gap sera calculado no controller
      tireCompound: stint ? (stint.compound || '').toUpperCase() : null,
      pitStops: pits,
      status: null,
    };
  });

  // Calcula gaps (diferenca de tempo para o lider)
  const leaderLap = bestLaps[results[0]?.driverNumber];
  if (leaderLap && leaderLap.lap_duration) {
    for (const r of results) {
      if (r.position === 1) {
        r.gap = 'LEADER';
      } else {
        const driverLap = bestLaps[r.driverNumber];
        if (driverLap && driverLap.lap_duration) {
          const diff = driverLap.lap_duration - leaderLap.lap_duration;
          r.gap = `+${diff.toFixed(3)}`;
        }
      }
    }
  }

  return { results, raceControl };
}

// Busca informacoes dos pilotos da OpenF1 (para mapeamento driver_number -> info)
async function getDrivers(sessionKey) {
  const data = await fetchOpenF1(`/drivers?session_key=${sessionKey}`);
  if (!Array.isArray(data)) return {};

  const drivers = {};
  for (const d of data) {
    drivers[d.driver_number] = {
      driverNumber: d.driver_number,
      abbreviation: d.name_acronym,
      firstName: d.first_name,
      lastName: d.last_name,
      teamName: d.team_name,
    };
  }

  return drivers;
}

module.exports = {
  fetchOpenF1,
  getSessionKey,
  getPositions,
  getBestLaps,
  getStints,
  getPitStops,
  getRaceControlMessages,
  fetchSessionData,
  getDrivers,
  formatLapTime,
  SESSION_TYPE_MAP,
};
