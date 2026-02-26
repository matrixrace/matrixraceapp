// Script para criar o usuário administrador do sistema
// Cria no Firebase + banco de dados + define como admin + transfere ligas oficiais
// Execute com: node scripts/create-admin.js

const { Pool } = require('pg');
const admin = require('firebase-admin');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const ADMIN_EMAIL = 'matrixracearena@gmail.com';
const ADMIN_PASSWORD = '656587';
const ADMIN_NAME = 'Matrix Race Admin';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

// Inicializa Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  }),
});

async function createAdmin() {
  const client = await pool.connect();

  try {
    console.log('\n🔧 Criando administrador do sistema...\n');

    // 1. Cria ou busca o usuário no Firebase
    let firebaseUid;
    try {
      const existing = await admin.auth().getUserByEmail(ADMIN_EMAIL);
      firebaseUid = existing.uid;
      console.log('✓ Usuário já existe no Firebase:', firebaseUid);

      // Atualiza a senha caso tenha mudado
      await admin.auth().updateUser(firebaseUid, { password: ADMIN_PASSWORD });
      console.log('✓ Senha atualizada no Firebase');
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        const newUser = await admin.auth().createUser({
          email: ADMIN_EMAIL,
          password: ADMIN_PASSWORD,
          displayName: ADMIN_NAME,
          emailVerified: true,
        });
        firebaseUid = newUser.uid;
        console.log('✓ Usuário criado no Firebase:', firebaseUid);
      } else {
        throw err;
      }
    }

    // 2. Cria ou atualiza o usuário no banco de dados
    const existingDb = await client.query(
      'SELECT id, is_admin FROM users WHERE email = $1 OR firebase_uid = $2',
      [ADMIN_EMAIL, firebaseUid]
    );

    let adminUserId;
    if (existingDb.rows.length > 0) {
      adminUserId = existingDb.rows[0].id;
      await client.query(
        'UPDATE users SET is_admin = true, display_name = $1, email = $2, firebase_uid = $3 WHERE id = $4',
        [ADMIN_NAME, ADMIN_EMAIL, firebaseUid, adminUserId]
      );
      console.log('✓ Usuário atualizado no banco de dados');
    } else {
      const inserted = await client.query(
        `INSERT INTO users (firebase_uid, email, display_name, is_admin)
         VALUES ($1, $2, $3, true) RETURNING id`,
        [firebaseUid, ADMIN_EMAIL, ADMIN_NAME]
      );
      adminUserId = inserted.rows[0].id;
      console.log('✓ Usuário inserido no banco de dados');
    }

    // 3. Remove admin do usuário de teste
    const removed = await client.query(
      "UPDATE users SET is_admin = false WHERE email != $1 AND is_admin = true RETURNING email",
      [ADMIN_EMAIL]
    );
    if (removed.rows.length > 0) {
      removed.rows.forEach(u => console.log(`✓ Admin removido de: ${u.email}`));
    }

    // 4. Transfere ownership das ligas oficiais para o novo admin
    const transferred = await client.query(
      'UPDATE leagues SET owner_id = $1 WHERE is_official = true RETURNING invite_code',
      [adminUserId]
    );
    console.log(`✓ ${transferred.rows.length} ligas oficiais transferidas para o novo admin`);

    // 5. Garante que o novo admin é membro de todas as ligas oficiais
    const officialLeagues = await client.query(
      'SELECT id FROM leagues WHERE is_official = true'
    );
    for (const league of officialLeagues.rows) {
      await client.query(
        'INSERT INTO league_members (league_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [league.id, adminUserId]
      );
    }
    console.log(`✓ Admin adicionado como membro das ${officialLeagues.rows.length} ligas oficiais`);

    console.log('\n✅ Administrador configurado com sucesso!');
    console.log(`   Email: ${ADMIN_EMAIL}`);
    console.log(`   Firebase UID: ${firebaseUid}`);
    console.log(`   DB ID: ${adminUserId}`);
    console.log('\n   Reinicie o backend para que as permissões funcionem.');

  } catch (error) {
    console.error('\n❌ Erro:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
    process.exit(0);
  }
}

createAdmin().catch((err) => {
  console.error('Falhou:', err.message);
  process.exit(1);
});
