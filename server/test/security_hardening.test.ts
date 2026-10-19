import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { SecurityMiddleware } from '../src/security_middleware';

describe('PowerBid: Security Hardening & Data-Leak Prevention Tests', function () {
  this.timeout(15000);
  const PORT = 3020;
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

  it('1. Rejects bids from non-room members (PB-SEC-05)', async () => {
    const hostSocket = createClient();
    const rogueSocket = createClient();
    await Promise.all([waitForConnect(hostSocket), waitForConnect(rogueSocket)]);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, res);
    });
    expect(createRes.success).to.be.true;

    await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    await new Promise((r) => setTimeout(r, 250));

    // Rogue user attempts to bid without joining room
    const rogueBidRes: any = await new Promise((res) => {
      rogueSocket.emit('place_bid', { roomCode: createRes.roomCode, bidAmount: 250 }, res);
    });

    expect(rogueBidRes.success).to.be.false;
    expect(rogueBidRes.error).to.include('Unauthorized: You are not a member');
  });

  it('2. Rejects pass_item from non-room members (PB-SEC-05)', async () => {
    const hostSocket = createClient();
    const rogueSocket = createClient();
    await Promise.all([waitForConnect(hostSocket), waitForConnect(rogueSocket)]);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, res);
    });

    await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    await new Promise((r) => setTimeout(r, 250));

    const roguePassRes: any = await new Promise((res) => {
      rogueSocket.emit('pass_item', { roomCode: createRes.roomCode }, res);
    });

    expect(roguePassRes.success).to.be.false;
    expect(roguePassRes.error).to.include('Unauthorized: You are not a member');
  });

  it('3. Rejects invalid room code formats (PB-SEC-06)', async () => {
    const socket = createClient();
    await waitForConnect(socket);

    const badCodes = ['INVALID!', '12', 'toolongcode123', 'DROP TABLE'];
    for (const code of badCodes) {
      const joinRes: any = await new Promise((res) => {
        socket.emit('join_room', { username: 'TestUser', roomCode: code }, res);
      });
      expect(joinRes.success).to.be.false;
      expect(joinRes.error).to.include('Invalid room code');
    }
  });

  it('4. Enforces profile update rate limiting (PB-SEC-04)', async () => {
    const socket = createClient();
    await waitForConnect(socket);

    // Initial 5 updates succeed
    for (let i = 1; i <= 5; i++) {
      const res: any = await new Promise((r) => {
        socket.emit('update_username', { username: `Name_${i}` }, r);
      });
      expect(res.success).to.be.true;
    }

    // 6th update should trigger rate limit
    const throttledRes: any = await new Promise((r) => {
      socket.emit('update_username', { username: 'Name_6' }, r);
    });
    expect(throttledRes.success).to.be.false;
    expect(throttledRes.error).to.include('Too many profile updates');
  });

  it('5. Ensures live auction never leaks individual item powerPoints or formulas (PB-SEC-09)', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    let leakedPointFound = false;
    hostSocket.on('item_announced', (data: any) => {
      if (data.currentItem && (data.currentItem.powerPoints !== undefined || data.currentItem.scoringMethod !== undefined)) {
        leakedPointFound = true;
      }
    });

    hostSocket.on('auction_state_update', (data: any) => {
      if (data.currentItem && (data.currentItem.powerPoints !== undefined || data.currentItem.scoringMethod !== undefined)) {
        leakedPointFound = true;
      }
    });

    const createRes: any = await new Promise((res) => {
      hostSocket.emit('create_room', { username: 'AuditHost', category: 'cricket', itemCount: 3 }, res);
    });

    await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });

    await new Promise((r) => setTimeout(r, 600));
    expect(leakedPointFound).to.be.false;
  });
});
