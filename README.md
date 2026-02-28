# Matrix Race App 3.0

Sistema de palpites para corridas de Fórmula 1 com ligas, ranking, amizades e chat em tempo real.

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | Node.js + Express |
| ORM | Drizzle ORM |
| Banco de dados | PostgreSQL (Railway) |
| Autenticação | Firebase Auth |
| Real-time | Socket.io |
| Imagens | Cloudinary |
| Frontend | Flutter Web |
| Navegação | GoRouter |
| Estado | flutter_bloc |

## Estrutura do projeto

```
MATRIX RACE APP 3.0/
├── backend/
│   ├── src/
│   │   ├── index.js                # Entrada do servidor
│   │   ├── routes/                 # Definição das rotas Express
│   │   ├── controllers/            # Handlers de cada rota
│   │   ├── middleware/             # Auth, validação, erros
│   │   ├── utils/                  # Validators (Zod), helpers, jolpica.js
│   │   └── db/
│   │       ├── schema/             # Schemas Drizzle (22 tabelas)
│   │       └── migrate.js
│   ├── public/                     # Build Flutter (servido em prod)
│   ├── .env.example
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── main.dart
    │   ├── routes/app_router.dart       # GoRouter — todas as rotas
    │   ├── core/
    │   │   ├── network/api_client.dart  # HTTP client com Firebase token
    │   │   └── widgets/main_shell.dart  # AppBar + BottomNav compartilhados
    │   └── features/                    # Módulos por feature
    │       ├── auth/
    │       ├── home/
    │       ├── leagues/
    │       ├── predictions/
    │       ├── rankings/
    │       ├── profile/
    │       ├── friends/
    │       ├── chat/
    │       ├── notifications/
    │       ├── f1results/
    │       └── admin/
    └── pubspec.yaml
```

## Funcionalidades principais

- **Autenticação** — cadastro e login via Firebase (email/senha)
- **Palpites** — usuário prevê o top-10 de pilotos de cada corrida
- **Ligas** — competições com membros, convite por código, ranking próprio
- **Chat em tempo real** — Socket.io por liga e mensagens privadas entre amigos
- **Ranking** — pontuação por liga e por corrida
- **Amizades** — solicitações, lista de amigos, chat privado
- **Notificações** — em tempo real e no sino do AppBar
- **Painel Admin** — gerencia corridas, pilotos, equipes, resultados e pontuação
- **Histórico F1** — resultados oficiais via Jolpica/Ergast API

## Banco de dados — principais tabelas

| Tabela | Descrição |
|--------|-----------|
| `users` | Usuários (Firebase UID, perfil, isAdmin) |
| `teams` | Equipes de F1 |
| `drivers` | Pilotos de F1 |
| `races` | Corridas (temporada, round, datas de sessões) |
| `raceResults` | Resultado oficial das corridas |
| `leagues` | Ligas criadas pelos usuários |
| `leagueMembers` | Membros de cada liga |
| `predictions` | Palpites (piloto + posição por corrida) |
| `predictionApplications` | Palpite aplicado a uma liga específica |
| `scores` | Pontuação calculada por liga/corrida |
| `friendships` | Amizades entre usuários |
| `messages` | Mensagens privadas |
| `notifications` | Notificações do sistema |
| `leaguePosts` | Posts no mural da liga |
| `leaguePolls` | Enquetes na liga |

## Rotas da API

**Base URL:** `http://localhost:3000/api/v1`

### Autenticação

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| POST | `/auth/register` | — | Registra usuário no banco |
| GET | `/auth/me` | ✅ | Retorna perfil do usuário logado |
| PUT | `/auth/me` | ✅ | Atualiza perfil |

### Corridas

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/races/all` | Todas as corridas |
| GET | `/races/upcoming` | Corridas futuras |
| GET | `/races/drivers` | Pilotos ativos |
| GET | `/races/:id` | Detalhes de uma corrida |

### Palpites

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/predictions` | Cria/atualiza palpite |
| POST | `/predictions/apply` | Aplica palpite a ligas |
| GET | `/predictions/race/:raceId` | Palpite do usuário para corrida |
| DELETE | `/predictions/race/:raceId` | Remove palpite |

### Ligas

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/leagues` | Ligas do usuário |
| POST | `/leagues` | Cria liga |
| GET | `/leagues/:id` | Detalhes da liga |
| POST | `/leagues/:id/join` | Entra na liga |
| POST | `/leagues/join-by-code` | Entra via código de convite |
| GET | `/leagues/:id/messages` | Chat da liga |

### Rankings

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/rankings/league/:leagueId` | Ranking geral da liga |
| GET | `/rankings/league/:leagueId/race/:raceId` | Ranking por corrida |

### Admin (requer `isAdmin = true`)

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/admin/dashboard` | Estatísticas gerais |
| POST | `/admin/races/sync-schedule` | Sincroniza calendário via Jolpica API |
| POST | `/admin/races/:id/results` | Cadastra resultado oficial |
| POST | `/admin/races/:id/calculate-scores` | Calcula pontuação dos palpites |
| CRUD | `/admin/drivers` | Gerencia pilotos |
| CRUD | `/admin/teams` | Gerencia equipes |
| CRUD | `/admin/leagues` | Gerencia ligas oficiais |

### Histórico F1

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/f1-results?year=2024` | Resultados por temporada |
| GET | `/f1-results/drivers?year=2024` | Classificação de pilotos |
| GET | `/f1-results/constructors?year=2024` | Classificação de construtores |

## Variáveis de ambiente

Copie `backend/.env.example` para `backend/.env` e preencha:

```env
PORT=3000
DATABASE_URL=postgresql://usuario:senha@host:porta/database
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=...
SMTP_PASS=...
FRONTEND_URL=http://localhost:8080
```

## Como rodar (desenvolvimento)

### Backend

```bash
cd backend
npm install
npm run dev          # Inicia com nodemon na porta 3000
```

### Banco de dados

```bash
cd backend
npm run db:generate  # Gera arquivos de migração
npm run db:migrate   # Aplica migrações
npm run db:seed      # Popula dados iniciais
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=8080 --web-hostname=localhost
# Acesse: http://localhost:8080
```

## Deploy do frontend

O frontend Flutter é compilado e servido como arquivos estáticos pelo backend Express.

```bash
cd frontend
flutter build web --release
cp -r build/web/. ../backend/public/
```

Depois reinicie o backend. O app fica disponível em `http://localhost:3000`.

## Padrões do projeto

- Respostas da API seguem o formato `{ success, message, data }`
- Autenticação via header `Authorization: Bearer <firebase-token>`
- Datas armazenadas como UTC no banco; frontend converte com `.toLocal()` para exibição
- Rotas específicas (ex: `/races/sync-schedule`) declaradas **antes** de rotas com parâmetro (ex: `/races/:id`)
- Validação de entrada via schemas Zod em `backend/src/utils/validators.js`
