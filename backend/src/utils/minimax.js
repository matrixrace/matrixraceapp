const https = require('https');
const config = require('../config/environment');
const logger = require('./logger');

/**
 * Chama a API MiniMax (compatível com OpenAI Chat Completions).
 * Retorna o conteúdo da resposta como string.
 *
 * @param {string} systemPrompt - Instrução do sistema
 * @param {string} userMessage - Mensagem do usuário
 * @param {object} options - Opções adicionais (temperature, max_tokens)
 * @returns {Promise<string>} Conteúdo da resposta da IA
 */
function callMiniMax(systemPrompt, userMessage, options = {}) {
  return new Promise((resolve, reject) => {
    const apiKey = config.minimax?.apiKey;
    if (!apiKey) {
      return reject(new Error('MINIMAX_API_KEY não configurada'));
    }

    const baseUrl = config.minimax?.baseUrl || 'https://api.minimax.chat';
    const model = config.minimax?.model || 'MiniMax-M2.1';
    const url = new URL('/v1/chat/completions', baseUrl);

    const body = JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ],
      temperature: options.temperature ?? 0.3,
      max_tokens: options.max_tokens ?? 4096,
      response_format: { type: 'json_object' },
    });

    const reqOptions = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      timeout: 60000,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(reqOptions, (resp) => {
      let data = '';
      resp.on('data', (chunk) => { data += chunk; });
      resp.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.error) {
            return reject(new Error(`MiniMax API error: ${parsed.error.message || JSON.stringify(parsed.error)}`));
          }
          const content = parsed.choices?.[0]?.message?.content;
          if (!content) {
            return reject(new Error('MiniMax retornou resposta vazia'));
          }
          resolve(content);
        } catch (e) {
          reject(new Error(`Falha ao parsear resposta MiniMax: ${e.message}`));
        }
      });
    });

    req.on('error', (err) => reject(new Error(`MiniMax request error: ${err.message}`)));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Timeout ao chamar MiniMax API'));
    });

    req.write(body);
    req.end();
  });
}

/**
 * Chama MiniMax e retorna a resposta parseada como JSON.
 */
async function callMiniMaxJSON(systemPrompt, userMessage, options = {}) {
  const raw = await callMiniMax(systemPrompt, userMessage, options);
  // MiniMax M2.1 pode incluir <think>...</think> antes do JSON — remover
  const cleaned = raw.replace(/<think>[\s\S]*?<\/think>/g, '').trim();
  // Extrair o primeiro bloco JSON da resposta
  const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    logger.error(`[MiniMax] Nenhum JSON encontrado na resposta: ${raw.substring(0, 500)}`);
    throw new Error('MiniMax não retornou JSON válido');
  }
  try {
    return JSON.parse(jsonMatch[0]);
  } catch (e) {
    logger.error(`[MiniMax] JSON inválido: ${jsonMatch[0].substring(0, 500)}`);
    throw new Error('MiniMax não retornou JSON válido');
  }
}

module.exports = { callMiniMax, callMiniMaxJSON };
