import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { SecurityMiddleware } from '../src/security_middleware';
import { ProfileManager } from '../src/database/profile_manager';

describe('Step 9: Full Game End-to-End Multiplayer Integration Tests', function () {
  this.timeout(25000);
  const PORT = 3015;
  const SERVER_URL = `http://localhost:${PORT}`;
  let clientSockets: ClientSocket[] = [];

  before((done) => {
    startServer(PORT).then(() => done());
  });

  after((done) => {
    clientSockets.forEach((s) => s.close());
    server.close(() => done());
  });

  afterEach(() => {
    clientSockets.forEach((s) => s.close());
    clientSockets = [];
    SecurityMiddleware.resetRateLimits();
  });

  function createClient(): ClientSocket {
    const socket = Client(SERVER_URL, {
      transports: ['websocket'],
      forceNew: true,
    });
    clientSockets.push(socket);
    return socket;
  }

  function waitForConnect(socket: ClientSocket): Promise<void> {
    return new Promise((resolve) => {
      if (socket.connected) resolve();
      else socket.once('connect', () => resolve());
    });
  }

  it('1. Full 8-Player Lobby Synchronization and 9th Player Rejection', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    // Host creates room
    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'Player1_Host', category: 'Cricket', itemCount: 5 },
        res
      );
    });
    expect(createRes.success).to.be.true;
    const roomCode = createRes.roomCode;
    expect(roomCode).to.be.a('string');

    // 7 more players join (total 8)
    const guestSockets: ClientSocket[] = [];
    for (let i = 2; i <= 8; i++) {
      const guest = createClient();
      await waitForConnect(guest);
      const joinRes: any = await new Promise((res) => {
        guest.emit('join_room', { roomCode, username: `Player${i}` }, res);
      });
      expect(joinRes.success).to.be.true;
      guestSockets.push(guest);
    }

    // Verify room has exactly 8 players
    const room = roomManager.getRoom(roomCode);
    expect(room).to.not.be.undefined;
    expect(room?.players.length).to.equal(8);

    // Attempt 9th player join -> Must be rejected
    const ninthSocket = createClient();
    await waitForConnect(ninthSocket);
    const ninthRes: any = await new Promise((res) => {
      ninthSocket.emit('join_room', { roomCode, username: 'Player9_Overflow' }, res);
    });
    expect(ninthRes.success).to.be.false;
    expect(ninthRes.error).to.include('is full');
  });

  it('2. Authoritative Bidding, Passing, and Item Sale to Highest Bidder', async () => {
    const p1 = createClient();
    const p2 = createClient();
    await Promise.all([waitForConnect(p1), waitForConnect(p2)]);

    const createRes: any = await new Promise((res) => {
      p1.emit('create_room', { username: 'BidderHost', category: 'Cricket', itemCount: 5 }, res);
    });
    const code = createRes.roomCode;

    await new Promise((res) => {
      p2.emit('join_room', { roomCode: code, username: 'BidderGuest' }, res);
    });

    const startRes: any = await new Promise((res) => {
      p1.emit('start_auction', { roomCode: code }, res);
    });
    expect(startRes.success).to.be.true;

    // Wait for item announcement phase transition to BIDDING
    await new Promise((resolve) => setTimeout(resolve, 250));

    // P1 places valid opening bid of $300
    const bid1Res: any = await new Promise((res) => {
      p1.emit('place_bid', { roomCode: code, bidAmount: 300 }, res);
    });
    expect(bid1Res.success).to.be.true;

    // P2 outbids P1 with $350
    const bid2Res: any = await new Promise((res) => {
      p2.emit('place_bid', { roomCode: code, bidAmount: 350 }, res);
    });
    expect(bid2Res.success).to.be.true;

    // Non-integer bid should fail
    const invalidBidRes: any = await new Promise((res) => {
      p1.emit('place_bid', { roomCode: code, bidAmount: 360.5 }, res);
    });
    expect(invalidBidRes.success).to.be.false;

    // Both pass or timer progresses
    await new Promise((res) => {
      p1.emit('pass_item', { roomCode: code }, res);
    });
    await new Promise((res) => {
      p2.emit('pass_item', { roomCode: code }, res);
    });

    // Check room state reflects current highest bidder
    const engine = roomManager.getRoom(code)?.auctionEngine;
    expect(engine).to.not.be.undefined;
    expect(engine?.currentBid).to.equal(350);
  });

  it('3. Disconnect Seat Reservation and Reconnect via Session Token', async () => {
    const host = createClient();
    const guest = createClient();
    await Promise.all([waitForConnect(host), waitForConnect(guest)]);

    const createRes: any = await new Promise((res) => {
      host.emit('create_room', { username: 'GraceHost', category: 'Cricket', itemCount: 5 }, res);
    });
    const roomCode = createRes.roomCode;

    const joinRes: any = await new Promise((res) => {
      guest.emit('join_room', { roomCode, username: 'GraceGuest' }, res);
    });
    const guestSessionToken = joinRes.player.sessionToken;
    expect(guestSessionToken).to.be.a('string');

    // Guest suddenly disconnects
    guest.disconnect();
    await new Promise((res) => setTimeout(res, 100));

    // Seat should still be reserved
    let room = roomManager.getRoom(roomCode);
    expect(room?.players.length).to.equal(2);
    const seat = room?.players.find((p) => p.sessionToken === guestSessionToken);
    expect(seat?.isConnected).to.be.false;

    // Reconnect with new socket
    const reconnectedGuest = createClient();
    await waitForConnect(reconnectedGuest);

    const reconRes: any = await new Promise((res) => {
      reconnectedGuest.emit(
        'reconnect_room',
        { roomCode, sessionToken: guestSessionToken },
        res
      );
    });
    expect(reconRes.success).to.be.true;

    room = roomManager.getRoom(roomCode);
    const restoredSeat = room?.players.find((p) => p.sessionToken === guestSessionToken);
    expect(restoredSeat?.isConnected).to.be.true;
    expect(restoredSeat?.id).to.equal(reconnectedGuest.id);
  });

  it('4. Security checks: Non-host unauthorized start and setting modification', async () => {
    const host = createClient();
    const guest = createClient();
    await Promise.all([waitForConnect(host), waitForConnect(guest)]);

    const createRes: any = await new Promise((res) => {
      host.emit('create_room', { username: 'RealHost', category: 'Cricket', itemCount: 5 }, res);
    });
    const roomCode = createRes.roomCode;

    await new Promise((res) => {
      guest.emit('join_room', { roomCode, username: 'CheekyGuest' }, res);
    });

    // Guest tries to start auction
    const rogueStart: any = await new Promise((res) => {
      guest.emit('start_auction', { roomCode }, res);
    });
    expect(rogueStart.success).to.be.false;
    expect(rogueStart.error).to.include('host');

    // Guest tries to modify room settings
    const rogueSettings: any = await new Promise((res) => {
      guest.emit('update_room_settings', { roomCode, itemCount: 25 }, res);
    });
    expect(rogueSettings.success).to.be.false;
    expect(rogueSettings.error).to.include('host');
  });

  it('5. ProfileManager Idempotent Match Finalization & Stat Tracking', () => {
    const profileMgr = ProfileManager.getInstance();
    const profile = profileMgr.getOrCreateProfile('FinalUser');

    const matchPayload: any = {
      matchId: 'e2e_final_match_1001',
      category: 'cricket',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: profile.id,
      winnerName: 'FinalUser',
      isTie: false,
      participants: [
        {
          playerId: profile.id,
          username: 'FinalUser',
          rank: 1,
          itemsWon: 2,
          totalTeamPoints: 195,
          remainingBudget: 400,
          purchasedItems: [
            { itemId: 'c1', itemName: 'Sachin Tendulkar', price: 300, powerPoints: 99 },
            { itemId: 'c2', itemName: 'Virat Kohli', price: 300, powerPoints: 96 },
          ],
        },
      ],
    };

    const initialMatchesPlayed = profile.matchesPlayed;
    const initialWins = profile.matchesWon;

    // First finalization
    const res1 = profileMgr.recordCompletedMatch(matchPayload);
    expect(res1.success).to.be.true;
    expect(res1.isDuplicate).to.be.false;

    const updatedProfile = profileMgr.getProfileDTO(profile.id);
    expect(updatedProfile.matchesPlayed).to.equal(initialMatchesPlayed + 1);
    expect(updatedProfile.matchesWon).to.equal(initialWins + 1);

    // Duplicate match finalization attempt
    const res2 = profileMgr.recordCompletedMatch(matchPayload);
    expect(res2.success).to.be.true;
    expect(res2.isDuplicate).to.be.true;

    // Stats should NOT be incremented again
    const finalProfile = profileMgr.getProfileDTO(profile.id);
    expect(finalProfile.matchesPlayed).to.equal(initialMatchesPlayed + 1);
    expect(finalProfile.matchesWon).to.equal(initialWins + 1);
  });
});
