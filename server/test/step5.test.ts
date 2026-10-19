import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { CharacterDatabase } from '../src/database/db';
import { DataImporter } from '../src/database/importer';

describe('Step 5: Categories, Character Database, Power Points & Winner System Tests', function () {
  this.timeout(10000);
  const PORT = 3011;
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

  it('1. Should list all 11 categories with actual counts vs target counts', () => {
    const db = CharacterDatabase.getInstance();
    const categories = db.getCategorySummaryList();

    expect(categories).to.have.lengthOf(11);

    const cricket = categories.find((c) => c.id === 'cricket')!;
    expect(cricket.actualCount).to.equal(30);
    expect(cricket.targetCount).to.equal(800);
    expect(cricket.scoringMethod).to.include('ICC Career Performance');

    const naruto = categories.find((c) => c.id === 'naruto')!;
    expect(naruto.actualCount).to.equal(25);
    expect(naruto.targetCount).to.equal(250);

    const pokemon = categories.find((c) => c.id === 'pokemon')!;
    expect(pokemon.actualCount).to.equal(20);
    expect(pokemon.targetCount).to.equal(500);
  });

  it('2. Should validate imports, remove duplicates, and reject invalid scores', () => {
    const rawData = [
      { displayName: 'Valid Hero', powerPoints: 85, categoryId: 'test' },
      { displayName: 'Valid Hero', powerPoints: 85, categoryId: 'test' }, // Duplicate
      { displayName: '', powerPoints: 90, categoryId: 'test' }, // Missing name
      { displayName: 'Invalid Score High', powerPoints: 150, categoryId: 'test' }, // Out of range (>100)
      { displayName: 'Invalid Score Neg', powerPoints: -5, categoryId: 'test' }, // Negative
      { displayName: 'Invalid Score Float', powerPoints: 88.5, categoryId: 'test' }, // Non-integer
    ];

    const report = DataImporter.processAndValidate(rawData);

    expect(report.validCount).to.equal(1);
    expect(report.duplicateCount).to.equal(1);
    expect(report.invalidCount).to.equal(5);
    expect(report.validRecords[0].displayName).to.equal('Valid Hero');
  });

  it('3. Should select unique 5, 10 items, and reject if insufficient inventory', () => {
    const db = CharacterDatabase.getInstance();

    const items5 = db.getCharacterRecords('cricket', 5);
    expect(items5).to.have.lengthOf(5);
    const names5 = new Set(items5.map((i) => i.displayName));
    expect(names5.size).to.equal(5); // Unique selection

    const items10 = db.getCharacterRecords('naruto', 10);
    expect(items10).to.have.lengthOf(10);

    // Requesting more items than available valid records (e.g. 50 items when only 30 exist)
    expect(() => db.getCharacterRecords('cricket', 50)).to.throw(/Insufficient valid records/);
  });

  it('4. Should broadcast identical lineup & power points to all connected room clients', async () => {
    const client1 = createClient();
    const client2 = createClient();
    await waitForConnect(client1);
    await waitForConnect(client2);

    const createRes: any = await new Promise((resolve) => {
      client1.emit(
        'create_room',
        { username: 'HostUser', category: 'naruto', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 5 },
        resolve
      );
    });
    const roomCode = createRes.roomCode;

    await new Promise((resolve) => client2.emit('join_room', { username: 'GuestUser', roomCode }, resolve));

    const itemAnnouncedPromise1 = new Promise<any>((resolve) => client1.on('item_announced', resolve));
    const itemAnnouncedPromise2 = new Promise<any>((resolve) => client2.on('item_announced', resolve));

    await new Promise((resolve) => client1.emit('start_auction', { roomCode }, resolve));

    const evt1 = await itemAnnouncedPromise1;
    const evt2 = await itemAnnouncedPromise2;

    expect(evt1.currentItem.displayName).to.equal(evt2.currentItem.displayName);
    expect(evt1.currentItem.powerPoints).to.be.undefined;
    expect(evt2.currentItem.powerPoints).to.be.undefined;
  });

  it('5. Should handle Mode A (Character Power Comparison) direct text power resolution', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'cricket', gameMode: 'POWER_COMPARISON', itemCount: 5 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    const itemSoldPromise = new Promise<any>((resolve) => host.on('item_sold', resolve));

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const soldEvt = await itemSoldPromise;
    expect(soldEvt.winnerName).to.include('Sachin Tendulkar');
    expect(soldEvt.winnerName).to.not.include('Pts');
    expect(soldEvt.item.powerPoints).to.be.undefined;
  });

  it('6. Should handle Mode B (Auction Team Challenge) correctly calculating total team points', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'HostUser', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 2 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    // Simulate winning Item 1 (Sachin Tendulkar, 99 pts) for $300
    engine.placeBid(host.id!, 300);
    engine.finalizeItemSale();

    const standings = engine.calculateFinalStandings();

    expect(standings[0].playerName).to.equal('HostUser');
    expect(standings[0].rank).to.equal(1);
    expect(standings[0].itemsWon).to.equal(1);
    expect(standings[0].totalTeamPoints).to.equal(99);
    expect((standings[0].itemsList[0] as any).powerPoints).to.be.undefined;
    expect(standings[0].remainingBudget).to.equal(700);
  });

  it('7. Should verify pure text-only structure (no image URL properties)', () => {
    const db = CharacterDatabase.getInstance();
    const record = db.getCharacterRecords('naruto', 1)[0];

    expect(record).to.not.have.property('imageUrl');
    expect(record).to.not.have.property('imagePath');
    expect(record).to.not.have.property('thumbnail');
    expect(record.displayName).to.be.a('string');
    expect(record.powerPoints).to.be.a('number');
  });
});
