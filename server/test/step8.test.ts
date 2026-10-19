import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { SecurityMiddleware } from '../src/security_middleware';

describe('Step 8: Multiplayer Security, Anti-Cheating & Reconnection Tests', function () {
  this.timeout(15000);
  const PORT = 3014;
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

  it('1. Reject invalid bid amounts (negative, float, zero)', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5 },
        res
      );
    });

    const startRes: any = await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    expect(startRes.success).to.be.true;

    // Test float bid
    const floatRes: any = await new Promise((res) => {
      hostSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 150.75 }, res);
    });
    expect(floatRes.success).to.be.false;
    expect(floatRes.error).to.include('positive integer');

    // Test negative bid
    const negRes: any = await new Promise((res) => {
      hostSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: -100 }, res);
    });
    expect(negRes.success).to.be.false;

    // Test zero bid
    const zeroRes: any = await new Promise((res) => {
      hostSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 0 }, res);
    });
    expect(zeroRes.success).to.be.false;
  });

  it('2. Reject bids exceeding player remaining budget', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5 },
        res
      );
    });

    await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    await new Promise((r) => setTimeout(r, 250));

    const overBidRes: any = await new Promise((res) => {
      hostSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 2000 }, res);
    });

    expect(overBidRes.success).to.be.false;
    expect(overBidRes.error).to.include('Insufficient budget');
  });

  it('3. Enforce rate limits on room creation and room code attempts', async () => {
    const client = createClient();
    await waitForConnect(client);

    // Perform 5 creations (allowed)
    for (let i = 0; i < 5; i++) {
      const res: any = await new Promise((r) => {
        client.emit('create_room', { username: `User${i}`, category: 'Cricket', itemCount: 5 }, r);
      });
      expect(res.success).to.be.true;
    }

    // 6th attempt should be blocked by rate limit
    const blockedRes: any = await new Promise((r) => {
      client.emit('create_room', { username: 'Abuser', category: 'Cricket', itemCount: 5 }, r);
    });
    expect(blockedRes.success).to.be.false;
    expect(blockedRes.error).to.include('Rate limit exceeded');
  });

  it('4. Preserve player seat & state during disconnect and restore on reconnect', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Naruto', itemCount: 5 },
        res
      );
    });

    const sessionToken = createRes.player.sessionToken;
    const roomCode = createRes.roomCode;
    expect(sessionToken).to.exist;

    // Simulate connection drop
    hostSocket.close();
    await new Promise((r) => setTimeout(r, 200));

    // Reconnect with new socket and session token
    const reconnectSocket = createClient();
    await waitForConnect(reconnectSocket);

    const reconnectRes: any = await new Promise((res) => {
      reconnectSocket.emit(
        'reconnect_room',
        { sessionToken, roomCode },
        res
      );
    });

    expect(reconnectRes.success).to.be.true;
    expect(reconnectRes.roomCode).to.equal(roomCode);
    expect(reconnectRes.player.name).to.equal('HostUser');
    expect(reconnectRes.player.sessionToken).to.equal(sessionToken);
  });

  it('5. Release seat after disconnect grace period expires', async () => {
    const hostSocket = createClient();
    const guestSocket = createClient();
    await waitForConnect(hostSocket);
    await waitForConnect(guestSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5 },
        res
      );
    });

    const joinRes: any = await new Promise((res) => {
      guestSocket.emit(
        'join_room',
        { username: 'GuestUser', roomCode: createRes.roomCode },
        res
      );
    });

    // Trigger disconnect for guest with short 300ms grace period for test
    const room = roomManager.getRoom(createRes.roomCode);
    expect(room?.players.length).to.equal(2);

    expect(guestSocket.id).to.exist;
    roomManager.handleDisconnect(guestSocket.id!, 300); // 300ms grace
    guestSocket.close();

    await new Promise((r) => setTimeout(r, 450));

    // Grace period expired, guest should be removed
    expect(room?.players.length).to.equal(1);
  });

  it('6. Handle concurrent bids deterministically', async () => {
    const hostSocket = createClient();
    const guestSocket = createClient();
    await waitForConnect(hostSocket);
    await waitForConnect(guestSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5 },
        res
      );
    });

    await new Promise((res) => {
      guestSocket.emit(
        'join_room',
        { username: 'GuestUser', roomCode: createRes.roomCode },
        res
      );
    });

    await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    await new Promise((r) => setTimeout(r, 250));

    // Send two simultaneous bids for $300 (base price minimum)
    const [p1, p2]: any[] = await Promise.all([
      new Promise((res) => hostSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 300 }, res)),
      new Promise((res) => guestSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 300 }, res)),
    ]);

    // One must succeed ($300) and the second must be rejected because minNextBid is now $350
    const successes = [p1, p2].filter((r) => r.success);
    const failures = [p1, p2].filter((r) => !r.success);

    expect(successes.length).to.equal(1);
    expect(failures.length).to.equal(1);
  });
});
