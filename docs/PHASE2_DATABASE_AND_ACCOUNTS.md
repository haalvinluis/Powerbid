# PowerBid — Phase 2: Persistent PostgreSQL Database, Guest Accounts & Virtual Coin Rewards

## Executive Summary
Phase 2 implements enterprise-grade database persistence, device-persisted guest profiles, optional registered email/password accounts, transactional guest linking, virtual coin rewards, and idempotent transaction ledgers for PowerBid. All operations are strictly server-authoritative, and item points, team totals, and scoring formulas remain permanently hidden from mobile clients, API responses, Socket.IO broadcasts, and client-accessible storage.

---

## 1. Database Architecture & PostgreSQL Connection Pool

### Connection Pool Configuration (`server/src/database/pg_pool.ts`)
- **Singleton Connection Pool**: Shared `DatabasePool` managing pooling, query parameter binding, SSL handling, connection health checks, and graceful draining.
- **Fail-Fast Production Constraint**:
  - In `production` (`NODE_ENV === 'production'` or `DB_REQUIRED === 'true'`), the backend strictly enforces a persistent PostgreSQL database. If unreachable, the server immediately throws a fatal exception rather than silently falling back to ephemeral memory.
  - In `development` mode, it logs a clear warning and supports local in-memory fallback.
- **ACID Transaction Wrapper (`withTransaction`)**:
  - Wraps multi-table operations in `BEGIN ... COMMIT` with automatic `ROLLBACK` on error.
- **Automated Idempotent Migrations (`runMigrations`)**:
  - Automatically reads and applies pending SQL migration files in alphabetical order on startup.
  - Tracks executed versions in the `schema_migrations` table.

### Applied Schema Migrations (`server/migrations/`)
1. `001_friends_and_invitations.sql`:
   - `player_profiles`: Persistent profile record (`id`, `public_player_id`, `username`, `avatar_text`, stats).
   - `friendships`: Canonical bidirectional friendships where `user_a_id < user_b_id`.
   - `friend_requests`: Pending, accepted, and rejected friend requests.
   - `room_invitations`: Room codes, expiration timestamps, and status tracking.
   - `in_app_notifications`: Real-time notification log.
2. `002_accounts_and_rewards.sql`:
   - `user_accounts`: Registered email accounts (`email`, `password_hash`, `profile_id`, `is_guest`).
   - `auth_sessions`: Expiring, revocable sessions indexed by SHA-256 token hash (`pbt_...`).
   - `completed_matches`: Canonical match history records.
   - `match_participants`: Server-side scores and ranking per match (never transmitted to client).
   - `coin_transactions`: Idempotent virtual coin ledger with unique constraint `(player_id, reference_id, reason)`.

---

## 2. Persistent Device Guest Profiles

### Mobile Device Identity (`mobile/lib/services/auth_service.dart`)
- **Device Guest UUID**: Generates a permanent `pb_guest_<uuid>` upon first app launch and persists it in Android `SharedPreferences`.
- **Session Preservation**: Restarts and reinstalls with data retention seamlessly restore the same player profile and statistics without relying on ephemeral socket IDs.
- **Handshake Authentication**: On every Socket.IO connection, the mobile app sends `guestPlayerId` and `token` in the handshake `auth` payload, automatically binding the socket to the persistent profile.

---

## 3. Registered Accounts & Guest Account Linking

### Password Security (`server/src/database/auth_manager.ts`)
- **Password Hashing**: Uses `crypto.scrypt` with a cryptographically secure 16-byte random salt (`scrypt$16384$8$1$...`).
- **Validation**: Enforces valid email regex and minimum 8-character passwords with alphanumeric requirements.
- **Session Tokens**: Issues high-entropy `pbt_<64-hex-char>` tokens valid for 30 days. Tokens are hashed with SHA-256 before database insertion to prevent token exposure in database dumps.
- **Logout & Revocation**: Instant revocation sets `is_revoked = true` in `auth_sessions`.

### Safe Transactional Account Linking
- Guests can link their existing guest profile to an email and password via `linkGuestAccount`.
- **Preserved Data**: All matches won, games played, achievements, friend connections, and accumulated coin balance are preserved atomically inside a PostgreSQL transaction (`withTransaction`).
- **Takeover Prevention**: Rejects linking if the email is already registered to another account.

---

## 4. Virtual Coin Rewards & Transaction Ledger

### Server-Authoritative Reward Logic (`ProfileManager.awardMatchCoins`)
- **Winner (Rank 1)**: +150 virtual coins (`MATCH_WIN_REWARD`).
- **Runner-Up (Rank 2)**: +75 virtual coins (`MATCH_RUNNER_UP_REWARD`).
- **Participant**: +25 virtual coins (`MATCH_PARTICIPATION_REWARD`).
- **Idempotence**: Match awards are strictly recorded under `(player_id, reference_id, reason)`. Attempting to credit the same match ID a second time is safely ignored with 0 duplicate coins awarded.
- **Zero Real-Money / Zero Ads**: All currency is strictly in-game virtual reward points.

---

## 5. Security, Privacy & Zero Data Leaks

1. **Item Points & Scoring Privacy**:
   - Total team points, individual item power points, and scoring formulas remain 100% secret on the server.
   - Mobile DTOs (`PlayerProfileDTO`, `MatchParticipantDTO`, `AuthResponseDTO`) completely omit scoring formulas and point values.
2. **Database Credential Protection**:
   - Connection strings and database passwords are read strictly from environment variables (`DATABASE_URL`, `DB_PASSWORD`).
   - Errors from `DatabasePool` and `AuthManager` sanitize underlying database internals before returning responses.

---

## 6. Verification & Test Results

### Backend Test Suite (`npm test`)
- **11 Test Suites**: All 76 tests passing (100% pass rate).
- Covers database outage handling, idempotent migrations, password validation, duplicate email prevention, guest account linking, session revocation, idempotent coin crediting, and zero-score leaks.

### Flutter Mobile Test Suite (`flutter test`)
- **22 Unit & Widget Tests**: All passing (100% pass rate).
- Covers guest UUID generation and persistence, session token restoration from `SharedPreferences`, reactive coin balance tracking, and logout state transitions.
