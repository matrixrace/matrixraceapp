// Script para criar as tabelas no banco de dados
// Execute com: npm run db:migrate

const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

async function migrate() {
  const client = await pool.connect();

  try {
    console.log('Iniciando migração do banco de dados...\n');

    // Habilita extensão para gerar UUIDs
    await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');
    console.log('✓ Extensão uuid-ossp habilitada');

    // Adiciona colunas de localização ao usuário (se não existirem)
    await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT`);
    await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS country VARCHAR(100)`);
    await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS state   VARCHAR(100)`);
    await client.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS city    VARCHAR(100)`);
    console.log('✓ Colunas bio/country/state/city garantidas em users');

    // Tabela de usuários
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        firebase_uid VARCHAR(128) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        display_name VARCHAR(100),
        avatar_url TEXT,
        is_admin BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela users criada');

    // Tabela de equipes
    await client.query(`
      CREATE TABLE IF NOT EXISTS teams (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) UNIQUE NOT NULL,
        logo_url TEXT,
        color_primary VARCHAR(7),
        color_secondary VARCHAR(7),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela teams criada');

    // Tabela de pilotos
    await client.query(`
      CREATE TABLE IF NOT EXISTS drivers (
        id SERIAL PRIMARY KEY,
        team_id INTEGER REFERENCES teams(id) ON DELETE SET NULL,
        first_name VARCHAR(50) NOT NULL,
        last_name VARCHAR(50) NOT NULL,
        number INTEGER,
        photo_url TEXT,
        nationality VARCHAR(3),
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela drivers criada');

    // Tabela de corridas (com datas de FP1 e Classificação para controle de palpites)
    await client.query(`
      CREATE TABLE IF NOT EXISTS races (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        location VARCHAR(100) NOT NULL,
        country VARCHAR(3),
        circuit_name VARCHAR(100),
        fp1_date TIMESTAMP,          -- Sexta - TL1 (trava palpites tipo 'fp1')
        qualifying_date TIMESTAMP,   -- Sábado - Classificação (trava palpites tipo 'qualifying')
        race_date TIMESTAMP NOT NULL, -- Domingo - Corrida (trava palpites tipo 'race')
        season INTEGER NOT NULL,
        round INTEGER NOT NULL,
        is_completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(season, round)
      );
    `);
    console.log('✓ Tabela races criada');

    // Tabela de resultados das corridas
    await client.query(`
      CREATE TABLE IF NOT EXISTS race_results (
        id SERIAL PRIMARY KEY,
        race_id INTEGER REFERENCES races(id) ON DELETE CASCADE NOT NULL,
        driver_id INTEGER REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
        position INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(race_id, position),
        UNIQUE(race_id, driver_id)
      );
    `);
    console.log('✓ Tabela race_results criada');

    // Tabela de ligas
    await client.query(`
      CREATE TABLE IF NOT EXISTS leagues (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name VARCHAR(100) NOT NULL,
        description TEXT,
        owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        is_public BOOLEAN DEFAULT FALSE,
        is_official BOOLEAN DEFAULT FALSE,
        is_paid BOOLEAN DEFAULT FALSE,
        entry_fee DECIMAL(10, 2) DEFAULT 0,
        invite_code VARCHAR(10) UNIQUE,
        max_members INTEGER,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela leagues criada');

    // Tabela de corridas por liga
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_races (
        id SERIAL PRIMARY KEY,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        race_id INTEGER REFERENCES races(id) ON DELETE CASCADE NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(league_id, race_id)
      );
    `);
    console.log('✓ Tabela league_races criada');

    // Tabela de membros por liga
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_members (
        id SERIAL PRIMARY KEY,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        has_paid BOOLEAN DEFAULT FALSE,
        joined_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(league_id, user_id)
      );
    `);
    console.log('✓ Tabela league_members criada');

    // Tabela de palpites (1 palpite por usuário por corrida, independente de liga)
    await client.query(`
      CREATE TABLE IF NOT EXISTS predictions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        race_id INTEGER REFERENCES races(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        driver_id INTEGER REFERENCES drivers(id) ON DELETE CASCADE NOT NULL,
        predicted_position INTEGER NOT NULL,
        lock_type VARCHAR(20) NOT NULL DEFAULT 'race',
        max_points_per_driver INTEGER NOT NULL DEFAULT 10,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(race_id, user_id, predicted_position),
        UNIQUE(race_id, user_id, driver_id)
      );
    `);
    console.log('✓ Tabela predictions criada');

    // Tabela de aplicação de palpites em ligas
    await client.query(`
      CREATE TABLE IF NOT EXISTS prediction_applications (
        id SERIAL PRIMARY KEY,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        race_id INTEGER REFERENCES races(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        applied_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(league_id, race_id, user_id)
      );
    `);
    console.log('✓ Tabela prediction_applications criada');

    // Tabela de pontuações
    await client.query(`
      CREATE TABLE IF NOT EXISTS scores (
        id SERIAL PRIMARY KEY,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        race_id INTEGER REFERENCES races(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        points INTEGER NOT NULL DEFAULT 0,
        calculated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(league_id, race_id, user_id)
      );
    `);
    console.log('✓ Tabela scores criada');

    // Tabela de convites
    await client.query(`
      CREATE TABLE IF NOT EXISTS invitations (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        invited_by UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        email VARCHAR(255) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        expires_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(league_id, email)
      );
    `);
    console.log('✓ Tabela invitations criada');

    // =============================================
    // NOVAS COLUNAS EM TABELAS EXISTENTES
    // =============================================

    // Adiciona bio na tabela users (se não existir)
    await client.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
    `);
    console.log('✓ Coluna bio adicionada em users');

    // Adiciona chat_mode na tabela leagues (se não existir)
    await client.query(`
      ALTER TABLE leagues ADD COLUMN IF NOT EXISTS chat_mode VARCHAR(20) DEFAULT 'all';
    `);
    console.log('✓ Coluna chat_mode adicionada em leagues');

    // Adiciona requires_approval na tabela leagues (se não existir)
    await client.query(`
      ALTER TABLE leagues ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT FALSE;
    `);
    console.log('✓ Coluna requires_approval adicionada em leagues');

    // Adiciona status na tabela league_members (se não existir)
    await client.query(`
      ALTER TABLE league_members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
    `);
    console.log('✓ Coluna status adicionada em league_members');

    // =============================================
    // NOVAS TABELAS SOCIAIS
    // =============================================

    // Tabela de amizades
    await client.query(`
      CREATE TABLE IF NOT EXISTS friendships (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        requester_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        addressee_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(requester_id, addressee_id)
      );
    `);
    console.log('✓ Tabela friendships criada');

    // Tabela de mensagens (chat privado e de liga)
    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        sender_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela messages criada');

    // Tabela de notificações
    await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        type VARCHAR(50) NOT NULL,
        title VARCHAR(200) NOT NULL,
        body TEXT,
        data JSONB,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela notifications criada');

    // Tabela de permissões de chat por liga (modo 'selected')
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_chat_allowed (
        id SERIAL PRIMARY KEY,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        UNIQUE(league_id, user_id)
      );
    `);
    console.log('✓ Tabela league_chat_allowed criada');

    // =============================================
    // ÁREA DA LIGA — MURAL E ENQUETES
    // =============================================

    // Adiciona post_mode na tabela leagues
    await client.query(`
      ALTER TABLE leagues ADD COLUMN IF NOT EXISTS post_mode VARCHAR(20) DEFAULT 'all';
    `);
    console.log('✓ Coluna post_mode adicionada em leagues');

    // Tabela de posts do mural da liga
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_posts (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        type VARCHAR(20) NOT NULL DEFAULT 'text',
        content TEXT,
        is_pinned BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela league_posts criada');

    // Tabela de curtidas em posts
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_post_likes (
        id SERIAL PRIMARY KEY,
        post_id UUID REFERENCES league_posts(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(post_id, user_id)
      );
    `);
    console.log('✓ Tabela league_post_likes criada');

    // Tabela de comentários em posts
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_post_comments (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        post_id UUID REFERENCES league_posts(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela league_post_comments criada');

    // Tabela de enquetes (vinculada a um post)
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_polls (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        post_id UUID REFERENCES league_posts(id) ON DELETE CASCADE NOT NULL,
        question TEXT NOT NULL,
        expires_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
    console.log('✓ Tabela league_polls criada');

    // Tabela de opções de enquete
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_poll_options (
        id SERIAL PRIMARY KEY,
        poll_id UUID REFERENCES league_polls(id) ON DELETE CASCADE NOT NULL,
        text VARCHAR(200) NOT NULL,
        order_index INTEGER NOT NULL
      );
    `);
    console.log('✓ Tabela league_poll_options criada');

    // Tabela de votos em enquetes
    await client.query(`
      CREATE TABLE IF NOT EXISTS league_poll_votes (
        id SERIAL PRIMARY KEY,
        poll_id UUID REFERENCES league_polls(id) ON DELETE CASCADE NOT NULL,
        option_id INTEGER REFERENCES league_poll_options(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(poll_id, user_id)
      );
    `);
    console.log('✓ Tabela league_poll_votes criada');

    // Criar índices para melhor performance
    console.log('\nCriando índices...');

    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);',
      'CREATE INDEX IF NOT EXISTS idx_drivers_team ON drivers(team_id);',
      'CREATE INDEX IF NOT EXISTS idx_drivers_active ON drivers(is_active);',
      'CREATE INDEX IF NOT EXISTS idx_races_date ON races(race_date);',
      'CREATE INDEX IF NOT EXISTS idx_races_season ON races(season, round);',
      'CREATE INDEX IF NOT EXISTS idx_league_members_user ON league_members(user_id);',
      'CREATE INDEX IF NOT EXISTS idx_league_members_league ON league_members(league_id);',
      'CREATE INDEX IF NOT EXISTS idx_predictions_user_race ON predictions(user_id, race_id);',
      'CREATE INDEX IF NOT EXISTS idx_pred_apps_league_race ON prediction_applications(league_id, race_id);',
      'CREATE INDEX IF NOT EXISTS idx_scores_league ON scores(league_id);',
      'CREATE INDEX IF NOT EXISTS idx_scores_user ON scores(user_id);',
      'CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);',
      'CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships(addressee_id);',
      'CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);',
      'CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);',
      'CREATE INDEX IF NOT EXISTS idx_messages_league ON messages(league_id);',
      'CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);',
      'CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);',
      'CREATE INDEX IF NOT EXISTS idx_league_posts_league ON league_posts(league_id);',
      'CREATE INDEX IF NOT EXISTS idx_league_posts_user ON league_posts(user_id);',
      'CREATE INDEX IF NOT EXISTS idx_league_post_likes_post ON league_post_likes(post_id);',
      'CREATE INDEX IF NOT EXISTS idx_league_post_comments_post ON league_post_comments(post_id);',
      'CREATE INDEX IF NOT EXISTS idx_league_poll_votes_poll ON league_poll_votes(poll_id);',
    ];

    for (const idx of indexes) {
      await client.query(idx);
    }
    console.log('✓ Todos os índices criados');

    console.log('\n✅ Migração concluída com sucesso!');
    console.log('Todas as tabelas foram criadas no banco de dados.\n');

  } catch (error) {
    console.error('❌ Erro na migração:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((err) => {
  console.error('Migração falhou:', err);
  process.exit(1);
});
