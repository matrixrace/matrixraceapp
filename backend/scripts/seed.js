// Script para popular o banco de dados com dados iniciais
// Execute com: npm run db:seed

const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

// Equipes da F1 2026
const teamsData = [
  { name: 'Red Bull Racing', color_primary: '#3671C6', color_secondary: '#FFD700' },
  { name: 'Mercedes', color_primary: '#27F4D2', color_secondary: '#000000' },
  { name: 'Ferrari', color_primary: '#E80020', color_secondary: '#FFEB3B' },
  { name: 'McLaren', color_primary: '#FF8000', color_secondary: '#000000' },
  { name: 'Aston Martin', color_primary: '#229971', color_secondary: '#FFFFFF' },
  { name: 'Alpine', color_primary: '#0093CC', color_secondary: '#FF69B4' },
  { name: 'Williams', color_primary: '#64C4FF', color_secondary: '#FFFFFF' },
  { name: 'Racing Bulls', color_primary: '#6692FF', color_secondary: '#FFFFFF' },
  { name: 'Audi', color_primary: '#00A551', color_secondary: '#000000' },
  { name: 'Haas', color_primary: '#B6BABD', color_secondary: '#E10600' },
  { name: 'Cadillac', color_primary: '#1E3A5F', color_secondary: '#C0C0C0' },
];

// Pilotos da F1 2026
const driversData = [
  { first_name: 'Lando', last_name: 'Norris', number: 1, nationality: 'GBR', team: 'McLaren' },
  { first_name: 'Oscar', last_name: 'Piastri', number: 81, nationality: 'AUS', team: 'McLaren' },
  { first_name: 'George', last_name: 'Russell', number: 63, nationality: 'GBR', team: 'Mercedes' },
  { first_name: 'Kimi', last_name: 'Antonelli', number: 12, nationality: 'ITA', team: 'Mercedes' },
  { first_name: 'Max', last_name: 'Verstappen', number: 3, nationality: 'NLD', team: 'Red Bull Racing' },
  { first_name: 'Isack', last_name: 'Hadjar', number: 6, nationality: 'FRA', team: 'Red Bull Racing' },
  { first_name: 'Charles', last_name: 'Leclerc', number: 16, nationality: 'MCO', team: 'Ferrari' },
  { first_name: 'Lewis', last_name: 'Hamilton', number: 44, nationality: 'GBR', team: 'Ferrari' },
  { first_name: 'Alexander', last_name: 'Albon', number: 23, nationality: 'THA', team: 'Williams' },
  { first_name: 'Carlos', last_name: 'Sainz', number: 55, nationality: 'ESP', team: 'Williams' },
  { first_name: 'Liam', last_name: 'Lawson', number: 30, nationality: 'NZL', team: 'Racing Bulls' },
  { first_name: 'Arvid', last_name: 'Lindblad', number: 41, nationality: 'GBR', team: 'Racing Bulls' },
  { first_name: 'Fernando', last_name: 'Alonso', number: 14, nationality: 'ESP', team: 'Aston Martin' },
  { first_name: 'Lance', last_name: 'Stroll', number: 18, nationality: 'CAN', team: 'Aston Martin' },
  { first_name: 'Pierre', last_name: 'Gasly', number: 10, nationality: 'FRA', team: 'Alpine' },
  { first_name: 'Franco', last_name: 'Colapinto', number: 43, nationality: 'ARG', team: 'Alpine' },
  { first_name: 'Esteban', last_name: 'Ocon', number: 31, nationality: 'FRA', team: 'Haas' },
  { first_name: 'Oliver', last_name: 'Bearman', number: 87, nationality: 'GBR', team: 'Haas' },
  { first_name: 'Nico', last_name: 'Hulkenberg', number: 27, nationality: 'DEU', team: 'Audi' },
  { first_name: 'Gabriel', last_name: 'Bortoleto', number: 5, nationality: 'BRA', team: 'Audi' },
  { first_name: 'Sergio', last_name: 'Perez', number: 11, nationality: 'MEX', team: 'Cadillac' },
  { first_name: 'Valtteri', last_name: 'Bottas', number: 77, nationality: 'FIN', team: 'Cadillac' },
];

// Corridas F1 2026 com datas aproximadas de FP1 e Classificação
// fp1_date = Sexta, qualifying_date = Sábado, race_date = Domingo
const racesData = [
  { name: 'GP da Austrália',      location: 'Melbourne',      country: 'AUS', circuit: 'Albert Park',                     fp1: '2026-03-06 01:30', quali: '2026-03-07 05:00', race: '2026-03-08 05:00', round: 1 },
  { name: 'GP da China',          location: 'Xangai',         country: 'CHN', circuit: 'Shanghai International Circuit',  fp1: '2026-03-13 03:30', quali: '2026-03-14 07:00', race: '2026-03-15 07:00', round: 2 },
  { name: 'GP do Japão',          location: 'Suzuka',         country: 'JPN', circuit: 'Suzuka Circuit',                  fp1: '2026-03-27 02:30', quali: '2026-03-28 06:00', race: '2026-03-29 06:00', round: 3 },
  { name: 'GP do Bahrein',        location: 'Sakhir',         country: 'BHR', circuit: 'Bahrain International Circuit',   fp1: '2026-04-10 11:30', quali: '2026-04-11 15:00', race: '2026-04-12 15:00', round: 4 },
  { name: 'GP da Arábia Saudita', location: 'Jeddah',         country: 'SAU', circuit: 'Jeddah Corniche Circuit',         fp1: '2026-04-17 13:30', quali: '2026-04-18 17:00', race: '2026-04-19 17:00', round: 5 },
  { name: 'GP de Miami',          location: 'Miami',          country: 'USA', circuit: 'Miami International Autodrome',   fp1: '2026-05-01 11:30', quali: '2026-05-02 15:00', race: '2026-05-03 15:00', round: 6 },
  { name: 'GP do Canadá',         location: 'Montreal',       country: 'CAN', circuit: 'Circuit Gilles Villeneuve',       fp1: '2026-05-22 10:30', quali: '2026-05-23 14:00', race: '2026-05-24 14:00', round: 7 },
  { name: 'GP de Mônaco',         location: 'Monte Carlo',    country: 'MCO', circuit: 'Circuit de Monaco',               fp1: '2026-06-05 11:30', quali: '2026-06-06 15:00', race: '2026-06-07 15:00', round: 8 },
  { name: 'GP da Catalunya',      location: 'Barcelona',      country: 'ESP', circuit: 'Circuit de Barcelona-Catalunya',  fp1: '2026-06-12 11:30', quali: '2026-06-13 15:00', race: '2026-06-14 15:00', round: 9 },
  { name: 'GP da Áustria',        location: 'Spielberg',      country: 'AUT', circuit: 'Red Bull Ring',                   fp1: '2026-06-26 11:30', quali: '2026-06-27 15:00', race: '2026-06-28 15:00', round: 10 },
  { name: 'GP da Grã-Bretanha',   location: 'Silverstone',    country: 'GBR', circuit: 'Silverstone Circuit',             fp1: '2026-07-03 11:30', quali: '2026-07-04 15:00', race: '2026-07-05 15:00', round: 11 },
  { name: 'GP da Bélgica',        location: 'Spa',            country: 'BEL', circuit: 'Circuit de Spa-Francorchamps',   fp1: '2026-07-17 11:30', quali: '2026-07-18 15:00', race: '2026-07-19 15:00', round: 12 },
  { name: 'GP da Hungria',        location: 'Budapeste',      country: 'HUN', circuit: 'Hungaroring',                    fp1: '2026-07-24 11:30', quali: '2026-07-25 15:00', race: '2026-07-26 15:00', round: 13 },
  { name: 'GP da Holanda',        location: 'Zandvoort',      country: 'NLD', circuit: 'Circuit Zandvoort',               fp1: '2026-08-21 11:30', quali: '2026-08-22 15:00', race: '2026-08-23 15:00', round: 14 },
  { name: 'GP da Itália',         location: 'Monza',          country: 'ITA', circuit: 'Autodromo Nazionale di Monza',    fp1: '2026-09-04 11:30', quali: '2026-09-05 15:00', race: '2026-09-06 15:00', round: 15 },
  { name: 'GP da Espanha',        location: 'Madrid',         country: 'ESP', circuit: 'Madring Street Circuit',          fp1: '2026-09-11 11:30', quali: '2026-09-12 15:00', race: '2026-09-13 15:00', round: 16 },
  { name: 'GP do Azerbaijão',     location: 'Baku',           country: 'AZE', circuit: 'Baku City Circuit',               fp1: '2026-09-25 07:30', quali: '2026-09-26 11:00', race: '2026-09-27 11:00', round: 17 },
  { name: 'GP de Singapura',      location: 'Singapura',      country: 'SGP', circuit: 'Marina Bay Street Circuit',       fp1: '2026-10-09 09:30', quali: '2026-10-10 13:00', race: '2026-10-11 13:00', round: 18 },
  { name: 'GP dos Estados Unidos', location: 'Austin',        country: 'USA', circuit: 'Circuit of the Americas',        fp1: '2026-10-23 10:30', quali: '2026-10-24 14:00', race: '2026-10-25 14:00', round: 19 },
  { name: 'GP do México',         location: 'Cidade do México', country: 'MEX', circuit: 'Autodromo Hermanos Rodriguez', fp1: '2026-10-30 10:30', quali: '2026-10-31 14:00', race: '2026-11-01 14:00', round: 20 },
  { name: 'GP do Brasil',         location: 'São Paulo',      country: 'BRA', circuit: 'Interlagos',                     fp1: '2026-11-06 10:30', quali: '2026-11-07 14:00', race: '2026-11-08 14:00', round: 21 },
  { name: 'GP de Las Vegas',      location: 'Las Vegas',      country: 'USA', circuit: 'Las Vegas Strip Circuit',        fp1: '2026-11-19 02:30', quali: '2026-11-20 06:00', race: '2026-11-21 06:00', round: 22 },
  { name: 'GP do Qatar',          location: 'Lusail',         country: 'QAT', circuit: 'Lusail International Circuit',    fp1: '2026-11-27 09:30', quali: '2026-11-28 13:00', race: '2026-11-29 13:00', round: 23 },
  { name: 'GP de Abu Dhabi',      location: 'Abu Dhabi',      country: 'ARE', circuit: 'Yas Marina Circuit',             fp1: '2026-12-04 09:30', quali: '2026-12-05 13:00', race: '2026-12-06 13:00', round: 24 },
];

async function seed() {
  const client = await pool.connect();

  try {
    console.log('Iniciando seed do banco de dados...\n');

    // 0. Limpar dados antigos
    console.log('Limpando dados antigos...');
    await client.query('DELETE FROM scores');
    await client.query('DELETE FROM prediction_applications');
    await client.query('DELETE FROM predictions');
    await client.query('DELETE FROM race_results');
    await client.query('DELETE FROM league_races');
    await client.query('DELETE FROM league_members');
    await client.query('DELETE FROM invitations');
    await client.query('DELETE FROM leagues');
    await client.query('DELETE FROM races');
    await client.query('DELETE FROM drivers');
    await client.query('DELETE FROM teams');
    console.log('✓ Dados antigos removidos');

    // 1. Inserir equipes
    console.log('Inserindo equipes 2026...');
    for (const team of teamsData) {
      await client.query(
        `INSERT INTO teams (name, color_primary, color_secondary)
         VALUES ($1, $2, $3)
         ON CONFLICT (name) DO UPDATE SET color_primary = $2, color_secondary = $3`,
        [team.name, team.color_primary, team.color_secondary]
      );
    }
    console.log(`✓ ${teamsData.length} equipes inseridas`);

    // 2. Inserir pilotos
    console.log('Inserindo pilotos 2026...');
    for (const driver of driversData) {
      const teamResult = await client.query('SELECT id FROM teams WHERE name = $1', [driver.team]);
      const teamId = teamResult.rows[0]?.id;
      await client.query(
        `INSERT INTO drivers (first_name, last_name, number, nationality, team_id)
         VALUES ($1, $2, $3, $4, $5) ON CONFLICT DO NOTHING`,
        [driver.first_name, driver.last_name, driver.number, driver.nationality, teamId]
      );
    }
    console.log(`✓ ${driversData.length} pilotos inseridos`);

    // 3. Inserir corridas com datas FP1/Quali
    console.log('Inserindo corridas 2026...');
    const insertedRaceIds = [];
    for (const race of racesData) {
      const result = await client.query(
        `INSERT INTO races (name, location, country, circuit_name, fp1_date, qualifying_date, race_date, season, round)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 2026, $8)
         ON CONFLICT (season, round) DO UPDATE SET
           name = $1, location = $2, country = $3, circuit_name = $4,
           fp1_date = $5, qualifying_date = $6, race_date = $7
         RETURNING id`,
        [race.name, race.location, race.country, race.circuit,
         race.fp1, race.quali, race.race, race.round]
      );
      insertedRaceIds.push(result.rows[0].id);
    }
    console.log(`✓ ${racesData.length} corridas inseridas`);

    // 4. Criar 24 ligas oficiais (uma por GP), se já houver um admin
    const adminUser = await client.query('SELECT id FROM users WHERE is_admin = true LIMIT 1');

    if (adminUser.rows.length > 0) {
      const adminId = adminUser.rows[0].id;
      let leaguesCreated = 0;

      for (let i = 0; i < racesData.length; i++) {
        const race = racesData[i];
        const raceId = insertedRaceIds[i];
        const inviteCode = `OFF-R${String(race.round).padStart(2, '0')}`;

        const leagueResult = await client.query(
          `INSERT INTO leagues (name, description, owner_id, is_public, is_official, invite_code)
           VALUES ($1, $2, $3, true, true, $4)
           ON CONFLICT (invite_code) DO UPDATE
             SET name = $1, description = $2
           RETURNING id`,
          [
            `${race.name} - Oficial`,
            `Liga oficial do ${race.name} 2026. Aberta a todos!`,
            adminId,
            inviteCode,
          ]
        );
        const leagueId = leagueResult.rows[0].id;

        // Vincula apenas esta corrida à liga oficial
        await client.query(
          `INSERT INTO league_races (league_id, race_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [leagueId, raceId]
        );

        // Admin entra automaticamente na liga
        await client.query(
          `INSERT INTO league_members (league_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [leagueId, adminId]
        );

        leaguesCreated++;
      }
      console.log(`✓ ${leaguesCreated} ligas oficiais criadas (OFF-R01 a OFF-R${String(racesData.length).padStart(2, '0')})`);
    } else {
      console.log('⚠️  Ligas oficiais serão criadas após o primeiro login do admin.');
      console.log('   No painel admin, use "Criar Ligas Oficiais".');
    }

    console.log('\n✅ Seed concluído com sucesso!');
    console.log(`   - ${teamsData.length} equipes (incluindo Cadillac e Audi)`);
    console.log(`   - ${driversData.length} pilotos`);
    console.log(`   - ${racesData.length} corridas (temporada 2026) com datas FP1/Quali`);
    console.log(`   - Ligas oficiais: 1 por GP (se admin existir)`);

  } catch (error) {
    console.error('❌ Erro no seed:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch((err) => {
  console.error('Seed falhou:', err);
  process.exit(1);
});
