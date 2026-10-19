# PowerBid — System Architecture Document

## 1. System Overview

**PowerBid** is a real-time, room-based multiplayer mobile auction game for Android. 

- Up to **8 players** per room.
- Real-time room creation & joining via room codes.
- Text-focused UI displaying player names only (no images or cards) to maintain a lightweight Android download size (<50 MB).
- Core interaction: **BID** and **PASS** buttons per item turn.
- Datasets:
  - **Cricket Category**: 800 player names
  - **Naruto Category**: 250 character names

---

## 2. Component Architecture

```text
+------------------------------------+        +------------------------------------+
|       Mobile Client (Flutter)      |        |      Backend Server (Node.js)     |
|                                    |        |                                    |
|  +------------------------------+  | Socket |  +------------------------------+  |
|  | UI Layer (Room / Bidding)    | <----------> | Socket.IO Event Handler      |  |
|  +------------------------------+  |  .IO   |  +------------------------------+  |
|  | Socket Service Client        |  |        |  | Authoritative Auction Engine |  |
|  +------------------------------+  |        |  +------------------------------+  |
|                                    |        |  | Room & Player State Manager  |  |
|                                    |        |  +------------------------------+  |
|                                    |        |  | Database Layer (PostgreSQL)  |  |
|                                    |        |  +------------------------------+  |
+------------------------------------+        +------------------------------------+
```

### 2.1 Server Responsibilities (Authoritative Source)
- **State Management**: The server strictly maintains all official state: room membership, current item up for bid, highest active bid, active bidder ID, turn timers, player budgets, and acquired rosters.
- **Timer Execution**: Countdown timers run server-side to prevent client timing drift or clock manipulation.
- **Validation**: Every bid or pass is validated server-side against budget limits, minimum bid increments, turn eligibility, and room status.
- **Persistence**: Persists completed room results, match statistics, and audit logs to PostgreSQL.

### 2.2 Mobile Responsibilities (Client)
- **Display & Rendering**: Renders room code entry, lobby state, current item name, highest bid amount, timer countdowns, and BID/PASS action controls.
- **User Actions**: Captures BID and PASS button interactions and dispatches socket events to the backend.
- **State Synchronization**: Updates local UI reactively upon receiving state snapshot updates from the backend server.

---

## 3. Communication Protocol (Socket.IO Events)

All client-server interactions use asynchronous Socket.IO events over WebSockets.

### 3.1 Room Management Events
- `room:create` (Client -> Server): Request room creation (select category: Cricket/Naruto).
- `room:join` (Client -> Server): Request join via 6-character room code.
- `room:state_update` (Server -> Client): Broadcast updated player list, ready states, and room status.

### 3.2 Auction State Events
- `auction:start` (Server -> Client): Signals auction phase onset with initial item details.
- `auction:bid` (Client -> Server): Player places bid.
- `auction:pass` (Client -> Server): Player passes on current item.
- `auction:item_update` (Server -> Client): Broadcasts new highest bid, leading bidder ID, and remaining turn timer.
- `auction:item_sold` (Server -> Client): Announces item winner, winning price, and updated player budgets.
- `auction:completed` (Server -> Client): Concludes room auction and displays summary roster standings.

---

## 4. Size & Performance Guidelines (<50 MB Target)

1. **Text-Only Assets**: No heavy PNG/JPEG images or video assets. Character datasets stored as lightweight JSON text arrays.
2. **Minimal External Packages**: Exclude unused UI or animation libraries.
3. **App Bundle Optimization**: Enable Flutter Android `--split-per-abi` or App Bundle build outputs to ensure minimal APK footprint.
