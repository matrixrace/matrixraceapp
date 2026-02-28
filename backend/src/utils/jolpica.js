const https = require('https');

// Faz uma requisição HTTPS para qualquer URL da Jolpica API
// Retorna o JSON parseado ou lança um erro
function fetchJolpica(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { timeout: 15000 }, (resp) => {
      let data = '';

      resp.on('data', (chunk) => { data += chunk; });

      resp.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Falha ao parsear resposta da Jolpica API'));
        }
      });
    }).on('error', (err) => {
      reject(err);
    }).on('timeout', () => {
      reject(new Error('Timeout ao chamar Jolpica API'));
    });
  });
}

module.exports = { fetchJolpica };
