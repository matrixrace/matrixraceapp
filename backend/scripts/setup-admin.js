// Script para configurar o admin e criar as 24 ligas oficiais
// Execute com: node scripts/setup-admin.js seu-email@gmail.com

const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const email = process.argv[2];

if (!email) {
  console.error('❌ Informe o email do admin:');
  console.error('   node scripts/setup-admin.js seu-email@gmail.com');
  process.exit(1);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

async function setupAdmin() {
  const client = await pool.connect();

  try {
    console.log(`\nConfigurando admin para: ${email}\n`);

    // 1. Busca o usuário
    const userResult = await client.query(
      'SELECT id, display_name, is_admin FROM users WHERE email = $1',
      [email]
    );

    if (userResult.rows.length === 0) {
      console.error(`❌ Usuário não encontrado: ${email}`);
      console.error('   Cadastre-se no app primeiro, depois execute este script.');
      return;
    }

    const user = userResult.rows[0];

    // 2. Define como admin
    if (!user.is_admin) {
      await client.query('UPDATE users SET is_admin = true WHERE id = $1', [user.id]);
      console.log(`✓ ${user.display_name || email} agora é admin`);
    } else {
      console.log(`✓ ${user.display_name || email} já é admin`);
    }

    // 3. Cria as 24 ligas oficiais (uma por GP)
    console.log('\nCriando ligas oficiais...');
    const races = await client.query(
      'SELECT id, name, season, round FROM races ORDER BY round'
    );

    if (races.rows.length === 0) {
      console.error('❌ Nenhuma corrida encontrada. Execute npm run db:seed primeiro.');
      return;
    }

    let created = 0;
    let skipped = 0;

    for (const race of races.rows) {
      const inviteCode = `OFF-R${String(race.round).padStart(2, '0')}`;

      // Verifica se já existe
      const existing = await client.query(
        'SELECT id FROM leagues WHERE invite_code = $1',
        [inviteCode]
      );

      if (existing.rows.length > 0) {
        // Atualiza o dono para o admin atual
        await client.query(
          'UPDATE leagues SET owner_id = $1 WHERE invite_code = $2',
          [user.id, inviteCode]
        );
        skipped++;
        continue;
      }

      // Cria a liga oficial
      const leagueResult = await client.query(
        `INSERT INTO leagues (name, description, owner_id, is_public, is_official, invite_code)
         VALUES ($1, $2, $3, true, true, $4) RETURNING id`,
        [
          `${race.name} - Oficial`,
          `Liga oficial do ${race.name} ${race.season}. Aberta a todos!`,
          user.id,
          inviteCode,
        ]
      );
      const leagueId = leagueResult.rows[0].id;

      // Vincula a corrida
      await client.query(
        'INSERT INTO league_races (league_id, race_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [leagueId, race.id]
      );

      // Admin entra automaticamente
      await client.query(
        'INSERT INTO league_members (league_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [leagueId, user.id]
      );

      created++;
    }

    console.log(`✓ ${created} ligas criadas, ${skipped} já existiam`);

    console.log('\n✅ Configuração concluída!');
    console.log(`   Admin: ${email}`);
    console.log(`   Ligas oficiais: OFF-R01 a OFF-R${String(races.rows.length).padStart(2, '0')}`);
    console.log('\n   Reinicie o backend para que as permissões de admin funcionem.');

  } catch (error) {
    console.error('❌ Erro:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

setupAdmin().catch((err) => {
  console.error('Falhou:', err.message);
  process.exit(1);
});
