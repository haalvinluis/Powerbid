# PowerBid — Cloud Deployment & Infrastructure Plan

## 1. Executive Summary & Architecture Requirements

PowerBid is a real-time, server-authoritative multiplayer auction game. Its architectural requirements differ fundamentally from standard stateless REST APIs:
1. **Persistent WebSocket Connections**: Live auctions require persistent, low-latency, bidirectional Socket.IO connections with 1-second countdown timer broadcasts and instant bid reception.
2. **Stateful In-Memory Match Rooms**: During an active auction match, room state (leading bidder, active timer, passing status) is held in server memory for maximum responsiveness.
3. **Persistent Relational Database**: Player profiles, public Player IDs (`PB-XXXXXX`), friendships, friend requests, room invitation hashes, and match histories must persist permanently across server restarts.
4. **Low Cost with Zero Idle Sleep**: Services that "sleep" after 15 minutes of inactivity (such as Render Free Tier) cause 50+ second cold starts and drop active WebSocket connections, making them unsuitable for live multiplayer gaming.

---

## 2. Cloud Hosting Provider Comparison

| Provider / Tier | Architecture | WebSocket Support | Sleep / Cold Start Behavior | Database Support | Estimated Monthly Cost | Recommendation |
|---|---|---|---|---|---|---|
| **Railway (Hobby Tier)** | Managed Container PaaS | Native persistent WebSockets | **Never sleeps** while credit remains; instant deployments | Integrated PostgreSQL addon ($5 credit covers both) | **$5.00 / month** | **Recommended (Best balance of simplicity & performance)** |
| **Render (Starter Tier)** | Managed Container PaaS | Native persistent WebSockets | **Never sleeps** (Starter instance $7/mo) | Render Managed Postgres ($7/mo) or Free Supabase | **$7.00 - $14.00 / mo** | Good alternative; free tier has unacceptable sleep behavior |
| **Self-Hosted VPS (Hetzner CX22 / DO Droplet)** | Dedicated Linux VM (2 vCPU, 4GB RAM, 40GB SSD) | Full root control; Nginx/Caddy reverse proxy | **Always online 24/7/365**; zero cold starts | Containerized PostgreSQL on dedicated SSD volume | **$4.00 - $6.00 / month** | **Recommended (Lowest cost & highest capacity)** |
| **Fly.io (Shared-CPU)** | Edge Container VMs | Native WebSockets | Can scale to 0 unless `min_machines_running = 1` | Fly Postgres or external | **$3.50 - $6.00 / month** | Solid alternative; requires Fly CLI tooling |
| **Vercel / AWS Lambda** | Serverless Functions | **Incompatible** (max 10-60s execution timeout) | Severe cold starts; drops persistent sockets | External only | N/A | **Do Not Use** (Serverless cannot host stateful Socket.IO servers) |

---

## 3. Database Architecture & Low-Cost Storage

### Option A: Supabase Free Tier PostgreSQL (Recommended for PaaS)
- **Cost**: **$0.00 / month** (Free forever tier).
- **Storage**: 500 MB persistent storage (more than sufficient for hundreds of thousands of player profiles and match logs).
- **Features**: Built-in Connection Pooling (Supavisor / pgbouncer), SSL encryption, automated backups, browser-based SQL dashboard.
- **Connection**: Directly connect `pg.Pool` via `DATABASE_URL` with SSL enabled (`rejectUnauthorized: false` for managed certificates).

### Option B: Self-Hosted PostgreSQL on VPS Docker Compose
- **Cost**: **Included in the $4-$6/mo VPS price**.
- **Storage**: Tied directly to the VPS SSD volume (e.g. 40 GB on Hetzner).
- **Features**: Zero network latency (runs on `localhost:5432` beside the Node.js container), isolated private network, automated daily pg_dump cron backups.

---

## 4. Concurrency, Connection Limits & Sizing Analysis

- **Memory Footprint**:
  - The PowerBid Node.js server consumes **~60 MB to 95 MB of RAM** at idle.
  - Active auction rooms consume approximately **50 KB per 8-player room**.
  - A 1 GB RAM container / VM can comfortably support **500 to 1,000 concurrent active players** (over 60 simultaneous active auction rooms).
- **Bandwidth**:
  - WebSocket timer heartbeats and JSON state diffs average **~1.5 KB/s per active room**.
  - A standard 20 TB monthly bandwidth allowance (standard on VPS) supports virtually unlimited gameplay.
- **Horizontal Scaling Path (Future)**:
  - When scaling beyond a single server instance, Socket.IO provides the `@socket.io/redis-adapter` to distribute room broadcasts across multiple Node.js worker nodes connected to a Redis pub/sub cluster.

---

## 5. Security & Domain Configuration

1. **HTTPS / WSS Enforcement**:
   - Modern mobile platforms (Android 9+) enforce encrypted network traffic by default.
   - For PaaS (Railway / Render): Free automatic Let's Encrypt SSL is provisioned for all `*.up.railway.app` or custom domains.
   - For VPS: Caddy or Nginx with Certbot provides automated zero-touch HTTPS certificate renewal.
2. **Android Network Security**:
   - In production builds (`kReleaseMode`), `AppConfig.environment` switches to `production`, directing all traffic to the secure HTTPS/WSS domain.
   - Android App Links require serving `/.well-known/assetlinks.json` from the cloud root domain to verify app ownership.

---

## 6. Step-by-Step Cloud Deployment Procedure

### Phase A: Database Setup
1. Create a free PostgreSQL instance on [Supabase](https://supabase.com) (or provision Docker PostgreSQL on a VPS).
2. Open the SQL Editor and execute `server/migrations/001_friends_and_invitations.sql` to initialize all tables, unique constraints, and indexes.
3. Save the connection string (`postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres`).

### Phase B: Server Deployment (Railway / Render Example)
1. Initialize a Git repository and push the project code.
2. In Railway or Render, select **Deploy from GitHub Repository** and point to the `server/` directory.
3. Configure the Environment Variables:
   - `NODE_ENV`: `production`
   - `PORT`: `3000` (or leave default assigned by platform)
   - `CORS_ORIGIN`: `*`
   - `JWT_SECRET`: `[GENERATE_A_64_CHAR_RANDOM_STRING]`
   - `DB_HOST`: `[SUPABASE_HOST]`
   - `DB_PORT`: `5432`
   - `DB_NAME`: `postgres`
   - `DB_USER`: `postgres`
   - `DB_PASSWORD`: `[SUPABASE_DB_PASSWORD]`
   - `DB_SSL`: `true`
4. The server will build (`npm ci && npm run build`) and start (`node dist/index.js`).
5. Verify health: `curl https://your-server-name.up.railway.app/health`.

### Phase C: Mobile App Configuration & Production Build
1. In `mobile/lib/config/app_config.dart`, set `productionServerUrl` to your live domain:
   ```dart
   static const String productionServerUrl = 'https://your-server-name.up.railway.app';
   ```
2. Build the production release APK:
   ```bash
   flutter build apk --release --dart-define=ENV=production
   ```
3. Distribute or install the release APK on target Android phones. All players worldwide will seamlessly connect to the same authoritative cloud server without any local network or USB restrictions.

---

## 7. Next Steps & User Review

Before proceeding to Phase 2, please review these findings and confirm your preference:
1. **Cloud Hosting Preference**: Do you prefer a **fully managed PaaS** (such as Railway or Render, ~$5-$7/mo) or a **dedicated VPS** (such as Hetzner or DigitalOcean, ~$4-$6/mo)?
2. **Account System Roadmap**: In Phase 2, should we implement device-persisted guest accounts (instant play, zero login required) alongside optional email/password registered accounts?
3. **Database Migration Wiring**: Should we wire `ProfileManager` and `FriendsManager` to write through to PostgreSQL on the cloud instance?
