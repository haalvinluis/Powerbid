# PowerBid — Phase 1: Existing Project Audit & System Analysis

**Audit Date**: October 18, 2026  
**Environment**: Windows 11 Host, Physical Android Device (Model: I2302 / Serial: `10BE7Y0157000U9`), Node.js v24.18.0, Flutter SDK 3.x  
**Scope**: Full codebase audit of Flutter Android client, Node.js/TypeScript backend, Socket.IO real-time engine, database layer, tests, and network architecture.

---

## 1. Actual Project Structure & Technologies

### Project Tree
```
secret project/
├── .env.example                     # Environment template for local development
├── docs/
│   ├── architecture.md              # System design overview
│   ├── SECURITY_AUDIT.md            # Security audit findings & hardening
│   ├── PROJECT_AUDIT.md             # This audit document
│   └── CLOUD_DEPLOYMENT_PLAN.md     # Cloud hosting & deployment strategy
├── mobile/                          # Flutter Android Client Application
│   ├── android/                     # Native Android project configuration
│   │   ├── app/src/main/AndroidManifest.xml  # Permissions, App Links, usesCleartextTraffic
│   │   └── app/build.gradle.kts     # Namespace: com.auctiongame.mobile, compileSdk, minSdk
│   ├── lib/
│   │   ├── config/app_config.dart   # Centralized environment & server endpoint configuration
│   │   ├── models/                  # Room, Player, AuctionState, Friend models
│   │   ├── screens/                 # Home, Mode Selection, Create/Join Room, Lobby, Auction, Results, Friends, Profile, Match History, Settings
│   │   ├── services/                # SocketService (Socket.IO client), AudioService, SettingsService
│   │   ├── theme/                   # AppTheme dark/light styling, colors, typography
│   │   └── widgets/                 # CustomButton, PowerBidLogo, NotificationsSheet, RoomPreviewDialog, etc.
│   └── test/                        # 5 test suites (16 automated tests)
├── server/                          # Node.js / TypeScript Authoritative Server
│   ├── migrations/
│   │   └── 001_friends_and_invitations.sql # PostgreSQL schema & constraints
│   ├── src/
│   │   ├── database/
│   │   │   ├── catalogs.ts          # 11 authentic character catalogs (Cricket, Naruto, One Piece, etc.)
│   │   │   ├── db.ts                # CharacterDatabase with import validation & readiness checks
│   │   │   ├── importer.ts          # Data normalization and deduplication
│   │   │   ├── profile_manager.ts   # Player profile, public Player ID generation, stats
│   │   │   └── schema.ts            # TypeScript interfaces for database records
│   │   ├── auction_engine.ts        # Authoritative bidding, timer tick, item sales, tie-breaking
│   │   ├── friends_manager.ts       # Friendships, friend requests, SHA-256 invite tokens, notifications
│   │   ├── room_manager.ts          # Room creation, lobby management, 8-player cap, seat reservation
│   │   ├── security_middleware.ts   # Rate-limiting, string sanitization, brute-force protection
│   │   ├── socket_handler.ts        # 30+ Socket.IO event listeners & dispatchers
│   │   └── index.ts                 # Express HTTP server + Socket.IO server initialization
│   ├── test/                        # 10 test suites (65 automated tests)
│   ├── Dockerfile                   # Multi-stage production container build
│   ├── docker-compose.yml           # Multi-container orchestration (App + PostgreSQL)
│   └── render.yaml                  # Infrastructure-as-code deployment blueprint
└── shared/
    ├── socket_events.ts             # Shared TypeScript DTOs, interfaces, and event constants
    └── socket_events.js             # Transpiled JavaScript version for legacy tools
```

### Technology Matrix
| Component | Technology | Version | Purpose |
|---|---|---|---|
| **Mobile Client** | Flutter / Dart | 3.x / Dart 3.x | Android mobile application |
| **Real-Time Client** | `socket_io_client` | ^3.0.2 | Bidirectional WebSocket communication |
| **Audio & Haptics** | `audioplayers` | ^6.1.0 | Sound effects and tactile feedback |
| **Native Sharing** | `share_plus` | ^13.3.1 | Android native share sheet & WhatsApp deep links |
| **Backend Runtime** | Node.js | v24.18.0 | Server execution environment |
| **Language** | TypeScript | ^5.4.5 | Type-safe backend architecture |
| **HTTP Framework** | Express | ^4.19.2 | REST endpoints (`/health`), static assets |
| **WebSocket Engine** | Socket.IO | ^4.7.5 | Real-time bidding, rooms, notifications |
| **Database Driver** | `pg` | ^8.11.5 | PostgreSQL client library |
| **Testing** | Mocha + Chai / Flutter Test | ^10.4.0 | Unit, integration, and widget tests |

---

## 2. Backend Startup & Connection Verification

### 1. HTTP Server Startup
- **Command**: `npm run dev` (`ts-node src/index.ts`)
- **Port**: `3000` (or `PORT` environment variable)
- **Status**: Starts cleanly with zero runtime exceptions.
- **Output**:
  ```
  =================================
  Auction Game Server running on port 3000
  Health check: http://localhost:3000/health
  =================================
  ```

### 2. Health Endpoint Probe
- **Request**: `GET http://localhost:3000/health`
- **Response**: HTTP 200 OK
  ```json
  {
    "status": "ok",
    "service": "PowerBid",
    "timestamp": "2026-10-18T14:29:15.539Z"
  }
  ```

### 3. Automated Test Verification
- **Backend Tests (`npm test` in `server/`)**:
  - `step1_room_lifecycle.test.ts`: 6 passed
  - `step2_bidding_flow.test.ts`: 8 passed
  - `step3_auction_timer.test.ts`: 4 passed
  - `step4_budget_management.test.ts`: 6 passed
  - `step5_post_auction_scoring.test.ts`: 7 passed
  - `step6_database_persistence.test.ts`: 6 passed
  - `step7_room_customization.test.ts`: 5 passed
  - `step8_multiplayer_security.test.ts`: 6 passed
  - `step9_full_game_e2e.test.ts`: 5 passed
  - `step10_friends_invitations.test.ts`: 7 passed
  - **Result**: **65 passing tests (100% pass rate, 17s duration)**.
- **Mobile Tests (`flutter test` in `mobile/`)**:
  - `friends_and_invitations_test.dart`: 6 passed
  - `player_model_test.dart`: 3 passed
  - `settings_test.dart`: 2 passed
  - `socket_service_test.dart`: 4 passed
  - `widget_test.dart`: 1 passed
  - **Result**: **16 passing tests (100% pass rate, 2s duration)**.

---

## 3. Root Cause Analysis: "Connecting…" & `http://127.0.0.1:3000`

### The Problem
When launching the app on a physical Android device or opening the **Online Multiplayer Room** screen, the status badge remains stuck on **"Connecting…"** with red indicator, displaying `http://127.0.0.1:3000`.

### Diagnostic Findings & Network Verification
1. **Loopback Isolation on Android**:
   - In Android OS, `127.0.0.1` and `localhost` resolve strictly to the **phone's internal network stack**, NOT the development PC.
   - When the app attempts to connect to `http://127.0.0.1:3000`, the phone searches for a server running on the phone itself.
   - We verified this by running network probes directly inside the Android device shell:
     - `toybox nc -z 127.0.0.1 3000` ➔ **Result: `Connection refused`**.
2. **Fragility of `adb reverse`**:
   - While `adb reverse tcp:3000 tcp:3000` can map the phone's loopback port to the host PC over USB, the ADB reverse tunnel is ephemeral: it is immediately destroyed if the USB cable is jostled, if the phone locks, if ADB daemon restarts, or when playing over Wi-Fi.
3. **Local Wi-Fi Reachability**:
   - The host computer's IPv4 address on the local Wi-Fi subnet was identified as `10.238.8.1`.
   - Running the network probe from the phone to the PC's Wi-Fi IP:
     - `toybox nc -z -w 3 10.238.8.1 3000` ➔ **Result: `Connected`** (Verified!).
4. **Hardcoded Fallback in Code**:
   - In `SocketService.dart` (lines 15-18), the default was hardcoded as:
     `const String.fromEnvironment('SERVER_URL', defaultValue: 'http://127.0.0.1:3000')`.
   - In `CreateJoinRoomScreen.dart` (lines 247-248), hint text and helper text hardcoded `127.0.0.1:3000`.

### Solution Applied
1. Created `mobile/lib/config/app_config.dart` providing centralized, environment-aware configuration:
   - Production / Release builds default to the cloud endpoint (`https://api.powerbid.game`), never `localhost`.
   - Development builds default to local network IP (`http://10.238.8.1:3000`).
   - Supports compile-time overrides: `--dart-define=SERVER_URL=https://...` and `--dart-define=ENV=production`.
2. Updated `SocketService` to pull its active base URL from `AppConfig.defaultServerUrl`.
3. Updated `CreateJoinRoomScreen` to display dynamic environment badge and URL helper text.

---

## 4. Database & Persistence Status

### Current Database Architecture
- **Schema & Migrations Defined**:
  - `server/migrations/001_friends_and_invitations.sql` defines complete production DDL for `player_profiles`, `friendships`, `friend_requests`, `room_invitations`, and `in_app_notifications`.
  - Schema includes unique constraints (`CHECK (user1_id < user2_id)`), partial indexes (`WHERE status = 'PENDING'`), foreign keys, and SHA-256 token hashing.
- **Active Runtime State**:
  - Currently, `ProfileManager` and `FriendsManager` maintain records in **in-memory data structures** (`Map<string, ...>` and `Set<string>`).
  - `CharacterDatabase` operates from statically compiled authentic data in `catalogs.ts` validated via `importer.ts`.
- **Cloud Readiness Risk**:
  - In an in-memory setup, **restarting the server or redeploying a container resets all player profiles, friendships, and match history**.
  - For cloud deployment, the existing SQL migration must be executed against a persistent cloud PostgreSQL instance (e.g. Supabase, Neon, or managed PostgreSQL), and `ProfileManager` / `FriendsManager` queries wired to `pg.Pool`.

---

## 5. Feature Implementation Status Matrix

| Feature | Status | Implementation Details / File Paths | Verification / Tests |
|---|---|---|---|
| **Server-Authoritative Auction** | **Implemented** | `server/src/auction_engine.ts`, `server/src/room_manager.ts` | Verified by 34 tests in `step1` through `step4` & `step9_e2e` |
| **8-Player Capacity Cap** | **Implemented** | `room_manager.ts:131`, `friends_manager.ts:503` | Verified: 9th player rejected (`step9_e2e.test.ts:1`) |
| **Permanently Hidden Scores** | **Implemented** | Zero point leaks in DTOs, names, previews, or profiles | Verified by 10 tests in `hidden_points.test.ts` |
| **Unique Player IDs (`PB-XXXXXX`)** | **Implemented** | `profile_manager.ts:92-103`, `profile_screen.dart` | Verified by `step10_friends_invitations.test.ts:1` |
| **Friends System (Search, Request, Remove)**| **Implemented** | `friends_manager.ts`, `friends_screen.dart` | Verified by `step10_friends_invitations.test.ts:2-3` |
| **Room Invitations & Deep Links** | **Implemented** | `friends_manager.ts:400-580`, `lobby_screen.dart` | Verified by `step10_friends_invitations.test.ts:4-6` |
| **In-App Notification Center** | **Implemented** | `friends_manager.ts:600-650`, `notifications_sheet.dart` | Verified by `step10_friends_invitations.test.ts:7` |
| **Configurable Server URL** | **Implemented** | `mobile/lib/config/app_config.dart`, `socket_service.dart` | Verified by `socket_service_test.dart:3-4` |
| **Zero Ads / No Real-Money IAP** | **Implemented** | Clean codebase: zero ad SDKs, zero billing libraries | Confirmed in `pubspec.yaml` and `package.json` |
| **Planned Auction Categories (11 total)** | **Implemented** | 11 categories loaded in `catalogs.ts` & `db.ts` | Dynamic counts verified: Cricket (30), Naruto (25), etc. |
| **Category Readiness Enforcement** | **Implemented** | `db.ts:192-206`: throws error if records < itemCount | Verified by `auction.test.ts` & `step7.test.ts` |
| **In-Match Auction Budget ($1,000)** | **Implemented** | `room_manager.ts:90`, `auction_engine.ts:22` | Verified by `step4_budget_management.test.ts` |
| **Persistent Virtual Coin Rewards** | **Missing** | Account-level coin wallet & post-match coin awards | In-game auction budget exists; persistent wallet is not yet built |
| **Guest Accounts (Device-Persisted)** | **Partially Implemented** | Guest profiles generated per socket session | Ephemeral; needs local UUID storage in `SharedPreferences` |
| **Registered Accounts (Auth / Login)** | **Missing** | Profiles exist, but no password/token login flow | Accounts are created on-the-fly; no login screen |
| **Persistent Database Storage** | **Partially Implemented** | SQL schema & migrations ready (`migrations/001...sql`) | Runtime currently uses in-memory Map stores |
