const https = require('https');
const http = require('http');
const { XMLParser } = require('fast-xml-parser');
const logger = require('./logger');

// Lista de feeds RSS de portais F1
const RSS_FEEDS = [
  { name: 'Motorsport.com', url: 'https://www.motorsport.com/rss/f1/news/' },
  { name: 'Autosport', url: 'https://www.autosport.com/rss/f1/news/' },
  { name: 'Formula 1 Official', url: 'https://www.formula1.com/en/latest/all.xml' },
  { name: 'BBC F1', url: 'https://feeds.bbci.co.uk/sport/formula1/rss.xml' },
  { name: 'ESPN F1', url: 'https://www.espn.com/espn/rss/f1/news' },
  { name: 'Sky Sports F1', url: 'https://www.skysports.com/rss/12040' },
  { name: 'The Race', url: 'https://www.the-race.com/rss/' },
  { name: 'GPFans', url: 'https://www.gpfans.com/en/rss.xml' },
  { name: 'F1i', url: 'https://f1i.com/feed' },
  { name: 'Pitpass', url: 'https://www.pitpass.com/fes_php/fes_usr_sit_newsfeed.php?fes_prepession_link=rss' },
];

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
});

/**
 * Faz um GET HTTP(S) e retorna o corpo como string.
 */
function fetchUrl(url, timeout = 10000) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    const req = client.get(url, { timeout, headers: { 'User-Agent': 'MatrixRaceBot/1.0' } }, (resp) => {
      // Seguir redirects (301, 302)
      if (resp.statusCode >= 300 && resp.statusCode < 400 && resp.headers.location) {
        return fetchUrl(resp.headers.location, timeout).then(resolve).catch(reject);
      }
      if (resp.statusCode !== 200) {
        return reject(new Error(`HTTP ${resp.statusCode}`));
      }
      let data = '';
      resp.on('data', (chunk) => { data += chunk; });
      resp.on('end', () => resolve(data));
    });
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
  });
}

/**
 * Parseia XML de RSS/Atom e retorna array normalizado de artigos.
 */
function parseRssFeed(xml, sourceName) {
  try {
    const parsed = parser.parse(xml);
    const articles = [];

    // RSS 2.0
    const channel = parsed?.rss?.channel;
    if (channel) {
      const items = Array.isArray(channel.item) ? channel.item : channel.item ? [channel.item] : [];
      for (const item of items) {
        articles.push({
          title: cleanText(item.title),
          link: item.link || '',
          description: cleanText(item.description || item['content:encoded'] || ''),
          pubDate: parseDate(item.pubDate),
          image: extractImage(item),
          sourceName,
        });
      }
      return articles;
    }

    // Atom
    const feed = parsed?.feed;
    if (feed) {
      const entries = Array.isArray(feed.entry) ? feed.entry : feed.entry ? [feed.entry] : [];
      for (const entry of entries) {
        const link = Array.isArray(entry.link)
          ? (entry.link.find(l => l['@_rel'] === 'alternate') || entry.link[0])
          : entry.link;
        articles.push({
          title: cleanText(typeof entry.title === 'object' ? entry.title['#text'] : entry.title),
          link: typeof link === 'object' ? link['@_href'] : link || '',
          description: cleanText(entry.summary || entry.content || ''),
          pubDate: parseDate(entry.published || entry.updated),
          image: null,
          sourceName,
        });
      }
      return articles;
    }

    return [];
  } catch (err) {
    logger.warn(`[RSS] Erro ao parsear feed de ${sourceName}: ${err.message}`);
    return [];
  }
}

/**
 * Busca todos os feeds RSS em paralelo e retorna array de artigos normalizados.
 * Filtra apenas artigos publicados nas últimas `hoursBack` horas.
 */
async function fetchAllFeeds(hoursBack = 5) {
  const cutoff = new Date(Date.now() - hoursBack * 60 * 60 * 1000);
  const results = await Promise.allSettled(
    RSS_FEEDS.map(async (feed) => {
      try {
        const xml = await fetchUrl(feed.url);
        return parseRssFeed(xml, feed.name);
      } catch (err) {
        logger.warn(`[RSS] Falha ao buscar ${feed.name}: ${err.message}`);
        return [];
      }
    })
  );

  const allArticles = [];
  for (const result of results) {
    if (result.status === 'fulfilled' && Array.isArray(result.value)) {
      allArticles.push(...result.value);
    }
  }

  // Filtrar por data e ordenar por mais recente
  return allArticles
    .filter(a => a.title && a.pubDate && a.pubDate >= cutoff)
    .sort((a, b) => b.pubDate - a.pubDate);
}

// --- Helpers ---

function cleanText(text) {
  if (!text) return '';
  if (typeof text !== 'string') text = String(text);
  // Remove tags HTML
  return text.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\s+/g, ' ').trim();
}

function parseDate(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  return isNaN(d.getTime()) ? null : d;
}

function extractImage(item) {
  // Tenta extrair imagem de media:content, media:thumbnail ou enclosure
  if (item['media:content']?.['@_url']) return item['media:content']['@_url'];
  if (item['media:thumbnail']?.['@_url']) return item['media:thumbnail']['@_url'];
  if (item.enclosure?.['@_url'] && item.enclosure?.['@_type']?.startsWith('image')) {
    return item.enclosure['@_url'];
  }
  return null;
}

module.exports = { fetchAllFeeds, RSS_FEEDS };
