const https = require('https');
const logger = require('./logger');

const BASE_URL = 'https://api.formula1dashboard.com/api/v1';

// Mapeamento session_type interno -> nome na API
const SESSION_TYPE_MAP = {
  'FP1': 'Practice 1',
  'FP2': 'Practice 2',
  'FP3': 'Practice 3',
  'qualifying': 'Qualifying',
  'sprint_qualifying': 'Sprint Qualifying',
  'sprint': 'Sprint',
  'race': 'Race',
};

// Mapeamento country code (nosso DB) -> country name (API)
const COUNTRY_MAP = {
  'AUS': 'Australia',
  'CHN': 'China',
  'CHI': 'China',
  'JPN': 'Japan',
  'JAP': 'Japan',
  'BHR': 'Bahrain',
  'BAH': 'Bahrain',
  'SAU': 'Saudi Arabia',
  'KSA': 'Saudi Arabia',
  'USA': 'United States',
  'MIA': 'United States',   // Miami GP
  'CAN': 'Canada',
  'MCO': 'Monaco',
  'MON': 'Monaco',
  'ESP': 'Spain',
  'SPA': 'Spain',
  'AUT': 'Austria',
  'GBR': 'Great Britain',
  'BEL': 'Belgium',
  'HUN': 'Hungary',
  'NLD': 'Netherlands',
  'NED': 'Netherlands',
  'ITA': 'Italy',
  'AZE': 'Azerbaijan',
  'SGP': 'Singapore',
  'SIN': 'Singapore',
  'MEX': 'Mexico',
  'BRA': 'Brazil',
  'QAT': 'Qatar',
  'ARE': 'Abu Dhabi',
  'UAE': 'Abu Dhabi',
  'ABU': 'Abu Dhabi',
  'LAS': 'Las Vegas',
  'EMI': 'Emilia-Romagna',
};

// Cache para sessoes (evita chamar /sessions a cada refresh)
let _sessionsCache = null;
let _sessionsCacheTime = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5 minutos

// Faz requisicao HTTPS para a Formula1Dashboard API
function fetchAPI(path) {
  const url = path.startsWith('http') ? path : BASE_URL + path;
  logger.info('F1Dashboard API request: ' + url);

  return new Promise((resolve, reject) => {
    const options = {
      timeout: 30000,
      headers: {
        'User-Agent': 'MatrixRace/1.0',
        'Accept': 'application/json',
      },
    };
    https.get(url, options, (resp) => {
      let data = '';
      resp.on('data', (chunk) => { data += chunk; });
      resp.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve(parsed);
        } catch (e) {
          logger.error('F1Dashboard parse error. Status: ' + resp.statusCode + '. Body (200 chars): ' + data.slice(0, 200));
          reject(new Error('Falha ao parsear resposta da F1Dashboard API (status=' + resp.statusCode + ')'));
        }
      });
    }).on('error', (err) => {
      reject(err);
    }).on('timeout', function () {
      this.destroy();
      reject(new Error('Timeout ao chamar F1Dashboard API'));
    });
  });
}

// Busca sessoes com cache
async function getSessions() {
  const now = Date.now();
  if (_sessionsCache && (now - _sessionsCacheTime) < CACHE_TTL) {
    return _sessionsCache;
  }
  const sessions = await fetchAPI('/sessions');
  if (!Array.isArray(sessions) || sessions.length === 0) {
    throw new Error('Nenhuma sessao encontrada na API');
  }
  _sessionsCache = sessions;
  _sessionsCacheTime = now;
  return sessions;
}

// Busca o meeting_key para uma corrida do nosso DB
// Usa country code para matching ao inves de round index
async function findMeeting(year, countryCode, raceName) {
  const sessions = await getSessions();

  // Filtra sessoes do ano correto (exclui pre-season tests que nao tem Race)
  const yearSessions = sessions.filter(s => {
    if (!s.date_start) return false;
    const sYear = new Date(s.date_start).getFullYear();
    return sYear === year;
  });

  // Agrupa por meeting_key
  const meetings = {};
  for (const s of yearSessions) {
    if (!meetings[s.meeting_key]) {
      meetings[s.meeting_key] = {
        meeting_key: s.meeting_key,
        country: s.grand_prix?.country || '',
        sessions: [],
        firstDate: s.date_start,
      };
    }
    meetings[s.meeting_key].sessions.push(s);
  }

  // Filtra meetings que tem sessoes reais (nao pre-season tests)
  const realMeetings = Object.values(meetings).filter(m =>
    m.sessions.some(s => ['Practice 1', 'Qualifying', 'Race'].includes(s.session_name))
  );

  // Tenta match por country code
  const apiCountry = COUNTRY_MAP[countryCode] || '';
  let match = realMeetings.find(m =>
    m.country.toLowerCase() === apiCountry.toLowerCase()
  );

  // Fallback: tenta match parcial pelo nome do pais
  if (!match && raceName) {
    const nameWords = raceName.toLowerCase().split(/[\s-]+/);
    match = realMeetings.find(m => {
      const mc = m.country.toLowerCase();
      return nameWords.some(w => mc.includes(w) || w.includes(mc));
    });
  }

  if (!match) {
    throw new Error('Corrida nao encontrada na API para ' + countryCode + ' (' + apiCountry + ') em ' + year);
  }

  return match;
}

// Formata gap para string
function formatGap(gap) {
  if (gap === null || gap === undefined) return null;
  if (gap === 0) return 'LEADER';
  return '+' + Number(gap).toFixed(3);
}

// Busca todos os dados de uma sessao e retorna formatado
// Agora recebe countryCode e raceName do nosso DB em vez de round
async function fetchSessionData(year, round, sessionType, countryCode, raceName) {
  const sessionName = SESSION_TYPE_MAP[sessionType];
  if (!sessionName) throw new Error('Tipo de sessao invalido: ' + sessionType);

  const meeting = await findMeeting(year, countryCode, raceName);
  logger.info('Match encontrado: ' + meeting.country + ' (meeting_key=' + meeting.meeting_key + ')');

  // Verifica se a sessao especifica existe neste meeting
  const sessionInfo = meeting.sessions.find(s => s.session_name === sessionName);
  if (!sessionInfo) {
    throw new Error('Sessao ' + sessionName + ' nao encontrada para ' + meeting.country);
  }

  // Busca resultados pelo meeting_key
  const results = await fetchAPI('/results?meeting_key=' + meeting.meeting_key);

  if (!Array.isArray(results) || results.length === 0) {
    throw new Error('Nenhum resultado encontrado para ' + meeting.country + '. A sessao pode nao ter acontecido ainda.');
  }

  // Filtra pela sessao correta
  const sessionResults = results
    .filter(r => r.session_type === sessionName)
    .sort((a, b) => a.position - b.position);

  if (sessionResults.length === 0) {
    throw new Error('Nenhum resultado para ' + sessionName + ' em ' + meeting.country + '. A sessao pode nao ter acontecido ainda.');
  }

  // Sessoes de qualifying: calcular gap relativo ao P1 a partir dos tempos
  const isQualifying = sessionName.includes('Qualifying');
  let leaderTime = null;
  if (isQualifying && sessionResults.length > 0) {
    leaderTime = parseTimeToSeconds(sessionResults[0].time);
  }

  // Monta resultado formatado
  const formattedResults = sessionResults.map((r) => {
    let gap = null;

    if (r.position === 1) {
      gap = 'LEADER';
    } else if (isQualifying && r.time && leaderTime) {
      // Para qualifying: calcular gap a partir dos tempos individuais
      const driverTime = parseTimeToSeconds(r.time);
      if (driverTime) {
        gap = '+' + (driverTime - leaderTime).toFixed(3);
      }
    } else if (r.gap_to_leader !== null && r.gap_to_leader !== undefined && r.gap_to_leader !== 0) {
      // Gap normal da API (corridas/sprints) — ignora gap=0 para nao-lideres
      gap = formatGap(r.gap_to_leader);
    } else if (r.time && r.position > 1) {
      // Fallback: usa o campo time como gap string (ex: "+5.515")
      gap = r.time.startsWith('+') ? r.time : null;
    }

    return {
      driverNumber: r.driver_season?.driver?.driver_number || null,
      position: r.position,
      bestLapTime: r.time || null,
      gap,
      tireCompound: null,
      pitStops: 0,
      status: r.completion_status_code || null,
      driverCode: r.driver_season?.driver?.code || null,
      driverName: r.driver_name || null,
      teamName: r.team_name || null,
      laps: r.laps || null,
      points: r.points || null,
    };
  });

  let raceControl = [];

  logger.info('Sessao ' + sessionName + ' de ' + meeting.country + ': ' + formattedResults.length + ' pilotos');
  return { results: formattedResults, raceControl };
}

// Converte string de tempo "M:SS.mmm" para segundos
function parseTimeToSeconds(timeStr) {
  if (!timeStr) return null;
  const parts = timeStr.split(':');
  if (parts.length === 2) {
    return parseInt(parts[0]) * 60 + parseFloat(parts[1]);
  }
  return parseFloat(timeStr) || null;
}

// Formata duracao em segundos para "M:SS.mmm"
function formatLapTime(durationSeconds) {
  if (!durationSeconds) return null;
  const minutes = Math.floor(durationSeconds / 60);
  const seconds = (durationSeconds % 60).toFixed(3);
  return minutes + ':' + seconds.padStart(6, '0');
}

function invalidateSessionsCache() {
  _sessionsCache = null;
  _sessionsCacheTime = 0;
}

module.exports = {
  fetchAPI,
  findMeeting,
  fetchSessionData,
  formatLapTime,
  formatGap,
  invalidateSessionsCache,
  SESSION_TYPE_MAP,
  COUNTRY_MAP,
};
