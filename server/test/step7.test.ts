import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';

describe('Step 7: Room Customization & Settings Tests', function () {
  this.timeout(10000);
  const PORT = 3013;
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

  it('1. Host can update room settings (category, itemCount, timerDuration)', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    // Create room with default settings
    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Naruto', itemCount: 10 },
        res
      );
    });

    expect(createRes.success).to.be.true;
    expect(createRes.roomState.category).to.equal('Naruto');
    expect(createRes.roomState.itemCount).to.equal(10);
    expect(createRes.roomState.timerDuration).to.equal(15);

    // Update settings to Cricket, 25 items, 10s timer
    const updateRes: any = await new Promise((res) => {
      hostSocket.emit(
        'update_room_settings',
        {
          roomCode: createRes.roomCode,
          category: 'Cricket',
          itemCount: 25,
          timerDuration: 10,
        },
        res
      );
    });

    expect(updateRes.success).to.be.true;
    expect(updateRes.roomState.category).to.equal('Cricket');
    expect(updateRes.roomState.itemCount).to.equal(25);
    expect(updateRes.roomState.timerDuration).to.equal(10);
  });

  it('2. Non-host cannot update room settings', async () => {
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

    const updateRes: any = await new Promise((res) => {
      guestSocket.emit(
        'update_room_settings',
        {
          roomCode: createRes.roomCode,
          category: 'Naruto',
          itemCount: 10,
          timerDuration: 20,
        },
        res
      );
    });

    expect(updateRes.success).to.be.false;
    expect(updateRes.error).to.include('Only the room host can change room settings.');
  });

  it('3. Reject invalid timer duration (must be 10, 15, or 20)', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5 },
        res
      );
    });

    const updateRes: any = await new Promise((res) => {
      hostSocket.emit(
        'update_room_settings',
        {
          roomCode: createRes.roomCode,
          timerDuration: 30,
        },
        res
      );
    });

    expect(updateRes.success).to.be.false;
    expect(updateRes.error).to.include('Timer duration must be 10, 15, or 20 seconds.');
  });

  it('4. Lock room settings after auction starts', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5, timerDuration: 20 },
        res
      );
    });

    // Start auction
    const startRes: any = await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });
    expect(startRes.success).to.be.true;

    // Attempt to update settings during active auction
    const updateRes: any = await new Promise((res) => {
      hostSocket.emit(
        'update_room_settings',
        {
          roomCode: createRes.roomCode,
          itemCount: 10,
        },
        res
      );
    });

    expect(updateRes.success).to.be.false;
    expect(updateRes.error).to.include('cannot be changed after the auction has started');
  });

  it('5. Auction Engine respects configured timer duration (20s)', async () => {
    const hostSocket = createClient();
    await waitForConnect(hostSocket);

    const createRes: any = await new Promise((res) => {
      hostSocket.emit(
        'create_room',
        { username: 'HostUser', category: 'Cricket', itemCount: 5, timerDuration: 20 },
        res
      );
    });

    const startRes: any = await new Promise((res) => {
      hostSocket.emit('start_auction', { roomCode: createRes.roomCode }, res);
    });

    expect(startRes.success).to.be.true;
    expect(startRes.roomState.timerDuration).to.equal(20);

    const engine = roomManager.getAuctionEngine(createRes.roomCode);
    expect(engine).to.exist;
    expect(engine!.timerDuration).to.equal(20);
  });
});
