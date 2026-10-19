import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';

describe('Real-Time Room Networking Tests', () => {
  const PORT = 3009;
  const SERVER_URL = `http://localhost:${PORT}`;
  let clientSockets: ClientSocket[] = [];

  before((done) => {
    startServer(PORT).then(() => done());
  });

  after((done) => {
    clientSockets.forEach((s) => s.close());
    server.close(() => {
      done();
    });
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
      if (socket.connected) {
        resolve();
      } else {
        socket.once('connect', () => resolve());
      }
    });
  }

  it('1. Should create a room with a 6-character room code and set creator as host', async () => {
    const client = createClient();
    await waitForConnect(client);

    const res: any = await new Promise((resolve) => {
      client.emit(
        'create_room',
        { username: 'Alice', category: 'cricket', itemCount: 10 },
        resolve
      );
    });

    expect(res.success).to.be.true;
    expect(res.roomCode).to.be.a('string');
    expect(res.roomCode.length).to.equal(6);
    expect(res.player.name).to.equal('Alice');
    expect(res.player.isHost).to.be.true;
    expect(res.roomState.players).to.have.lengthOf(1);
  });

  it('2. Should allow a second client to join the room and receive synchronized state', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'naruto', itemCount: 10 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    const guest = createClient();
    await waitForConnect(guest);

    const statePromise = new Promise<any>((resolve) => {
      host.on('room_state', (updatedState: any) => {
        if (updatedState.players.length === 2) {
          resolve(updatedState);
        }
      });
    });

    const guestRes: any = await new Promise((resolve) => {
      guest.emit('join_room', { username: 'GuestUser', roomCode }, resolve);
    });

    expect(guestRes.success).to.be.true;
    expect(guestRes.roomState.players).to.have.lengthOf(2);

    const updatedState = await statePromise;
    expect(updatedState.players[1].name).to.equal('GuestUser');
  });

  it('3. Should reject joining an invalid room code', async () => {
    const client = createClient();
    await waitForConnect(client);

    const res: any = await new Promise((resolve) => {
      client.emit('join_room', { username: 'Bob', roomCode: 'INVALID99' }, resolve);
    });

    expect(res.success).to.be.false;
    expect(res.error).to.include('not found');
  });

  it('4. Should enforce maximum 8 players capacity and reject 9th player', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'Player1', category: 'anime', itemCount: 5 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    // Join 7 more players (Total 8)
    for (let i = 2; i <= 8; i++) {
      const guest = createClient();
      await waitForConnect(guest);
      const res: any = await new Promise((resolve) => {
        guest.emit('join_room', { username: `Player${i}`, roomCode }, resolve);
      });
      expect(res.success).to.be.true;
    }

    // 9th player attempt
    const ninthGuest = createClient();
    await waitForConnect(ninthGuest);
    const ninthRes: any = await new Promise((resolve) => {
      ninthGuest.emit(
        'join_room',
        { username: 'Player9_Excess', roomCode },
        resolve
      );
    });

    expect(ninthRes.success).to.be.false;
    expect(ninthRes.error).to.include('full');
  });

  it('5. Should reassign host when the original host leaves the room', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'OriginalHost', category: 'cricket', itemCount: 10 },
        resolve
      );
    });
    const roomCode = hostRes.roomCode;

    const guest = createClient();
    await waitForConnect(guest);

    await new Promise((resolve) => {
      guest.emit('join_room', { username: 'NextInLine', roomCode }, resolve);
    });

    const hostChangedPromise = new Promise<any>((resolve) => {
      guest.on('host_changed', resolve);
    });

    host.emit('leave_room', { roomCode });

    const evt = await hostChangedPromise;
    expect(evt.newHostName).to.equal('NextInLine');
    expect(evt.roomState.players).to.have.lengthOf(1);
    expect(evt.roomState.players[0].isHost).to.be.true;
  });

  it('6. Should cleanup room when all participants disconnect', async () => {
    const client = createClient();
    await waitForConnect(client);

    const res: any = await new Promise((resolve) => {
      client.emit(
        'create_room',
        { username: 'SoloUser', category: 'cricket', itemCount: 10 },
        resolve
      );
    });
    const code = res.roomCode;
    await new Promise((resolve) => {
      client.emit('leave_room', { roomCode: code }, resolve);
    });
    client.disconnect();
    await new Promise((resolve) => setTimeout(resolve, 150));
    expect(roomManager.getRoom(code)).to.be.undefined;
  });
});
