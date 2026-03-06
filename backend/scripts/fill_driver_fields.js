// Script para preencher country e abbreviation dos pilotos existentes
// Execute com: node scripts/fill_driver_fields.js

const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

const driverFields = [
  { first_name: 'Lando',     last_name: 'Norris',     country: 'Reino Unido',   abbreviation: 'NOR' },
  { first_name: 'Oscar',     last_name: 'Piastri',    country: 'Australia',     abbreviation: 'PIA' },
  { first_name: 'George',    last_name: 'Russell',    country: 'Reino Unido',   abbreviation: 'RUS' },
  { first_name: 'Kimi',      last_name: 'Antonelli',  country: 'Italia',        abbreviation: 'ANT' },
  { first_name: 'Max',       last_name: 'Verstappen', country: 'Holanda',       abbreviation: 'VER' },
  { first_name: 'Isack',     last_name: 'Hadjar',     country: 'Franca',        abbreviation: 'HAD' },
  { first_name: 'Charles',   last_name: 'Leclerc',    country: 'Monaco',        abbreviation: 'LEC' },
  { first_name: 'Lewis',     last_name: 'Hamilton',   country: 'Reino Unido',   abbreviation: 'HAM' },
  { first_name: 'Alexander', last_name: 'Albon',      country: 'Tailandia',     abbreviation: 'ALB' },
  { first_name: 'Carlos',    last_name: 'Sainz',      country: 'Espanha',       abbreviation: 'SAI' },
  { first_name: 'Liam',      last_name: 'Lawson',     country: 'Nova Zelandia', abbreviation: 'LAW' },
  { first_name: 'Arvid',     last_name: 'Lindblad',   country: 'Reino Unido',   abbreviation: 'LIN' },
  { first_name: 'Fernando',  last_name: 'Alonso',     country: 'Espanha',       abbreviation: 'ALO' },
  { first_name: 'Lance',     last_name: 'Stroll',     country: 'Canada',        abbreviation: 'STR' },
  { first_name: 'Pierre',    last_name: 'Gasly',      country: 'Franca',        abbreviation: 'GAS' },
  { first_name: 'Franco',    last_name: 'Colapinto',  country: 'Argentina',     abbreviation: 'COL' },
  { first_name: 'Esteban',   last_name: 'Ocon',       country: 'Franca',        abbreviation: 'OCO' },
  { first_name: 'Oliver',    last_name: 'Bearman',    country: 'Reino Unido',   abbreviation: 'BEA' },
  { first_name: 'Nico',      last_name: 'Hulkenberg', country: 'Alemanha',      abbreviation: 'HUL' },
  { first_name: 'Gabriel',   last_name: 'Bortoleto',  country: 'Brasil',        abbreviation: 'BOR' },
  { first_name: 'Sergio',    last_name: 'Perez',      country: 'Mexico',        abbreviation: 'PER' },
  { first_name: 'Valtteri',  last_name: 'Bottas',     country: 'Finlandia',     abbreviation: 'BOT' },
];

async function fill() {
  const client = await pool.connect();
  try {
    console.log('Preenchendo country e abbreviation dos pilotos...\n');
    let updated = 0;
    let notFound = 0;

    for (const d of driverFields) {
      const result = await client.query(
        `UPDATE drivers SET country = $1, abbreviation = $2, updated_at = NOW()
         WHERE first_name = $3 AND last_name = $4
         RETURNING id, first_name, last_name`,
        [d.country, d.abbreviation, d.first_name, d.last_name]
      );
      if (result.rowCount > 0) {
        console.log(`✓ ${d.first_name} ${d.last_name} → ${d.abbreviation} | ${d.country}`);
        updated++;
      } else {
        console.log(`⚠ Não encontrado: ${d.first_name} ${d.last_name}`);
        notFound++;
      }
    }

    console.log(`\n✅ Concluído: ${updated} atualizados, ${notFound} não encontrados.`);
  } catch (err) {
    console.error('Erro:', err.message);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

fill().catch(err => {
  console.error('Falhou:', err);
  process.exit(1);
});
