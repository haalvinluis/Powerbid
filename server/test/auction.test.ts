import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';

describe('Real-Time Auction Engine Integration Tests', function () {
  this.timeout(10000);
  const PORT = 3010;
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

  it('1. Should enforce host-only auction start (reject non-host start)', async () => {
    const host = createClient();
    const guest = createClient();
    await waitForConnect(host);
    await waitForConnect(guest);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => {
      guest.emit('join_room', { username: 'GuestUser', roomCode }, resolve);
    });

    // Non-host attempts to start auction
    const nonHostRes: any = await new Promise((resolve) => {
      guest.emit('start_auction', { roomCode }, resolve);
    });

    expect(nonHostRes.success).to.be.false;
    expect(nonHostRes.error).to.include('host can start');
  });

  it('2. Should allow host to start auction and announce initial item', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'naruto', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    const startedPromise = new Promise<any>((resolve) => {
      host.on('auction_started', resolve);
    });

    const announcedPromise = new Promise<any>((resolve) => {
      host.on('item_announced', resolve);
    });

    const startRes: any = await new Promise((resolve) => {
      host.emit('start_auction', { roomCode }, resolve);
    });

    expect(startRes.success).to.be.true;
    const startedEvt = await startedPromise;
    expect(startedEvt.roomCode).to.equal(roomCode);

    const announcedEvt = await announcedPromise;
    expect(announcedEvt.currentItem.name).to.equal('Naruto Uzumaki');
    expect(announcedEvt.itemIndex).to.equal(1);
    expect(announcedEvt.totalItems).to.equal(5);
  });

  it('3. Should accept valid bids, enforce minimum increment, and reject invalid bids', async () => {
    const host = createClient();
    const guest = createClient();
    await waitForConnect(host);
    await waitForConnect(guest);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => {
      guest.emit('join_room', { username: 'GuestUser', roomCode }, resolve);
    });

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    // Wait until phase transitions to BIDDING
    await new Promise<void>((resolve) => {
      host.on('auction_state_update', (st: any) => {
        if (st.phase === 'BIDDING') resolve();
      });
    });

    // 1. First bid below base price ($300)
    const lowBidRes: any = await new Promise((resolve) => {
      guest.emit('place_bid', { roomCode, bidAmount: 100 }, resolve);
    });
    expect(lowBidRes.success).to.be.false;
    expect(lowBidRes.error).to.include('below required minimum');

    // 2. Valid first bid ($300)
    const validBidRes: any = await new Promise((resolve) => {
      guest.emit('place_bid', { roomCode, bidAmount: 300 }, resolve);
    });
    expect(validBidRes.success).to.be.true;
    expect(validBidRes.currentBid).to.equal(300);

    // 3. Counter bid below min increment ($300 + $50 = $350 required, bidding $310)
    const lowCounterRes: any = await new Promise((resolve) => {
      host.emit('place_bid', { roomCode, bidAmount: 310 }, resolve);
    });
    expect(lowCounterRes.success).to.be.false;

    // 4. Valid counter bid ($350)
    const validCounterRes: any = await new Promise((resolve) => {
      host.emit('place_bid', { roomCode, bidAmount: 350 }, resolve);
    });
    expect(validCounterRes.success).to.be.true;
    expect(validCounterRes.currentBid).to.equal(350);
  });

  it('4. Should reject bids exceeding participant remaining budget', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    await new Promise<void>((resolve) => {
      host.on('auction_state_update', (st: any) => {
        if (st.phase === 'BIDDING') resolve();
      });
    });

    // Starting budget is $1000. Try bidding $1500.
    const excessiveBidRes: any = await new Promise((resolve) => {
      host.emit('place_bid', { roomCode, bidAmount: 1500 }, resolve);
    });

    expect(excessiveBidRes.success).to.be.false;
    expect(excessiveBidRes.error).to.include('budget');
  });

  it('5. Should enforce PASS rule (prevents further bids on current item only)', async () => {
    const host = createClient();
    const guest = createClient();
    await waitForConnect(host);
    await waitForConnect(guest);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'anime', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => guest.emit('join_room', { username: 'GuestUser', roomCode }, resolve));
    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    await new Promise<void>((resolve) => {
      host.on('auction_state_update', (st: any) => {
        if (st.phase === 'BIDDING') resolve();
      });
    });

    // Guest passes
    const passRes: any = await new Promise((resolve) => {
      guest.emit('pass_item', { roomCode }, resolve);
    });
    expect(passRes.success).to.be.true;

    // Guest tries to bid after passing
    const postPassBidRes: any = await new Promise((resolve) => {
      guest.emit('place_bid', { roomCode, bidAmount: 300 }, resolve);
    });

    expect(postPassBidRes.success).to.be.false;
    expect(postPassBidRes.error).to.include('passed on this item');
  });

  it('6. Should finalize sale, deduct budget exactly once, and mark item SOLD when winning bid exists', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    await new Promise<void>((resolve) => {
      host.on('auction_state_update', (st: any) => {
        if (st.phase === 'BIDDING') resolve();
      });
    });

    // Host bids $300
    await new Promise((resolve) => host.emit('place_bid', { roomCode, bidAmount: 300 }, resolve));

    // Force finalize sale
    const engine = roomManager.getAuctionEngine(roomCode);
    expect(engine).to.not.be.undefined;

    const itemSoldPromise = new Promise<any>((resolve) => {
      host.on('item_sold', resolve);
    });

    engine!.finalizeItemSale();

    const soldEvt = await itemSoldPromise;
    expect(soldEvt.price).to.equal(300);
    expect(soldEvt.winnerName).to.include('HostUser');

    // Verify budget deduction ($1000 - $300 = $700)
    const winnerPlayer = engine!.players.get(host.id!);
    expect(winnerPlayer!.budget).to.equal(700);
    expect(winnerPlayer!.acquiredItems).to.include('Sachin Tendulkar');
  });

  it('7. Should mark item UNSOLD when no bids are placed before timer expires', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'naruto', itemCount: 5 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const unsoldPromise = new Promise<any>((resolve) => {
      host.on('item_unsold', resolve);
    });

    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.finalizeItemSale();

    const unsoldEvt = await unsoldPromise;
    expect(unsoldEvt.item.name).to.equal('Naruto Uzumaki');
  });

  it('8. Should process concurrent bids sequentially without state corruption', async () => {
    const p1 = createClient();
    const p2 = createClient();
    await waitForConnect(p1);
    await waitForConnect(p2);

    const res1: any = await new Promise((resolve) => {
      p1.emit('create_room', { username: 'Bidder1', category: 'cricket', itemCount: 5 }, resolve);
    });
    const roomCode = res1.roomCode;

    await new Promise((resolve) => p2.emit('join_room', { username: 'Bidder2', roomCode }, resolve));
    await new Promise((resolve) => p1.emit('start_auction', { roomCode }, resolve));

    await new Promise<void>((resolve) => {
      p1.on('auction_state_update', (st: any) => {
        if (st.phase === 'BIDDING') resolve();
      });
    });

    // Concurrent bid attempts at $300 (base price for cricket item 1)
    const results = await Promise.all([
      new Promise<any>((resolve) => p1.emit('place_bid', { roomCode, bidAmount: 300 }, resolve)),
      new Promise<any>((resolve) => p2.emit('place_bid', { roomCode, bidAmount: 300 }, resolve)),
    ]);

    // Exactly one should succeed, one should fail (or ask for higher bid)
    const successCount = results.filter((r) => r.success === true).length;
    const failCount = results.filter((r) => r.success === false).length;

    expect(successCount).to.equal(1);
    expect(failCount).to.equal(1);
  });

  it('9. Should compute final deterministic standings upon match completion', async () => {
    const host = createClient();
    await waitForConnect(host);

    const hostRes: any = await new Promise((resolve) => {
      host.emit('create_room', { username: 'HostUser', category: 'cricket', itemCount: 2 }, resolve);
    });
    const roomCode = hostRes.roomCode;

    const engine = roomManager.getAuctionEngine(roomCode);
    expect(engine).to.be.undefined; // Not started yet

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const activeEngine = roomManager.getAuctionEngine(roomCode)!;

    // Simulate item 1 sold to host for $200
    activeEngine.currentBid = 200;
    activeEngine.leadingBidderId = host.id!;
    activeEngine.finalizeItemSale();

    const standings = activeEngine.calculateFinalStandings();
    expect(standings).to.have.lengthOf(1);
    expect(standings[0].rank).to.equal(1);
    expect(standings[0].itemsWon).to.equal(1);
    expect(standings[0].remainingBudget).to.equal(800);
  });
});
