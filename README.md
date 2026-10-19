# PowerBid — Multiplayer Auction Game (Monorepo)

**PowerBid** is an Android online multiplayer auction game targeting `<50 MB` download size, featuring authoritative real-time bidding rooms powered by Flutter, Node.js, TypeScript, Socket.IO, and PostgreSQL.

## Monorepo Layout

```text
auction-game/
├── mobile/     # Flutter Android client application
├── server/     # Node.js + TypeScript authoritative backend server
├── shared/     # Shared documentation, socket event types & contracts
├── docs/       # Architecture & development specifications
├── .env.example# Environment configuration template
└── README.md   # Project overview and setup guide
```

---

## Step 3 Real-Time Multiplayer Networking Setup

### 1. Starting the Authoritative Backend Server

1. Open PowerShell and navigate to `server/`:
   ```powershell
   cd server
   ```
2. Copy configuration (if not already done):
   ```powershell
   copy ..\.env.example .env
   ```
3. Install dependencies & run development server:
   ```powershell
   npm install
   npm run dev
   ```
   *Health check endpoint*: `http://localhost:3000/health`
4. Run automated test suite:
   ```powershell
   npm test
   ```

---

### 2. Running the Flutter Mobile Client

#### Option A: Android Emulator
Android Emulators cannot connect to `http://localhost:3000` directly. Flutter uses `http://10.0.2.2:3000` to alias the host development machine:
```powershell
cd mobile
flutter run --dart-define=SERVER_URL=http://10.0.2.2:3000
```

#### Option B: Two Physical Phones on the Same Wi-Fi Network
1. Find your host PC's IPv4 address on local Wi-Fi:
   ```powershell
   ipconfig
   ```
   *(Look for Wireless LAN adapter Wi-Fi IPv4 Address, e.g. `192.168.1.150`)*
2. Ensure Windows Firewall allows incoming connections on port `3000`.
3. Connect both Android phones to the same Wi-Fi network.
4. Launch the Flutter app on Phone 1 and Phone 2 pointing to your PC's IP:
   ```powershell
   cd mobile
   flutter run --dart-define=SERVER_URL=http://192.168.1.150:3000
   ```
   *(Or tap the Wifi Icon in the app's top bar on the Create/Join screen to change the Server URL dynamically)*.

#### Option C: Friends on Different Networks / Internet
- To play with users outside your local Wi-Fi, the server must be deployed to a publicly reachable domain/IP (e.g. Render, Railway, AWS, or an `ngrok http 3000` tunnel).

---

## Technical Stack & Constraints

- **Mobile Client**: Flutter + Dart (Target size: `<50 MB` APK/AAB). Text-only character/player rosters.
- **Backend**: Node.js + TypeScript (Authoritative source for rooms, max 8 capacity, host assignment, bids).
- **Networking**: Socket.IO (`socket_io_client`) for real-time bidirectional event synchronization.
- **Capacity**: Maximum 8 real human participants per room room code.
