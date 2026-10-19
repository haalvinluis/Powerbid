import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { CharacterDatabase } from '../src/database/db';
import { ProfileManager } from '../src/database/profile_manager';

describe('PowerBid: Hidden Points System Tests', function () {
  this.timeout(10000);
  const PORT = 3016;
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

  it('1. Item announcements never leak points, scoring formulas, or provenance', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'SecretHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 3 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    const itemAnnouncedPromise = new Promise<any>((resolve) => host.on('item_announced', resolve));
    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const itemEvt = await itemAnnouncedPromise;
    expect(itemEvt.currentItem.displayName).to.be.a('string');
    expect(itemEvt.currentItem.basePrice).to.be.a('number');
    expect(itemEvt.currentItem.powerPoints).to.be.undefined;
    expect(itemEvt.currentItem.scoringMethod).to.be.undefined;
    expect(itemEvt.currentItem.provenance).to.be.undefined;
  });

  it('2. Auction state updates never leak currentItem points, formulas, or provenance', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'StateHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 3 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    const statePromise = new Promise<any>((resolve) => host.on('auction_state_update', resolve));
    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const state = await statePromise;
    expect(state.currentItem).to.not.be.undefined;
    expect(state.currentItem.displayName).to.be.a('string');
    expect(state.currentItem.powerPoints).to.be.undefined;
    expect(state.currentItem.scoringMethod).to.be.undefined;
    expect(state.currentItem.provenance).to.be.undefined;
  });

  it('3. Item sold and unsold events never reveal item points or point formulas', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'SaleHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 2 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    const soldPromise = new Promise<any>((resolve) => host.on('item_sold', resolve));
    engine.placeBid(host.id!, 300);
    engine.finalizeItemSale();

    const soldEvt = await soldPromise;
    expect(soldEvt.item.displayName).to.be.a('string');
    expect(soldEvt.item.powerPoints).to.be.undefined;
    expect(soldEvt.item.scoringMethod).to.be.undefined;
    expect(soldEvt.winnerName).to.equal('SaleHost');
  });

  it('4. Mode A power resolution announces winner without revealing numeric points in name', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'ModeAHost', category: 'cricket', gameMode: 'POWER_COMPARISON', itemCount: 2 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    const soldPromise = new Promise<any>((resolve) => host.on('item_sold', resolve));
    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));

    const soldEvt = await soldPromise;
    expect(soldEvt.winnerName).to.be.a('string');
    expect(soldEvt.winnerName).to.not.include('Pts');
    expect(soldEvt.winnerName).to.not.include('(');
    expect(soldEvt.item.powerPoints).to.be.undefined;
  });

  it('5. Final standings reveal authoritative totalTeamPoints but keep individual item scores completely hidden', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'StandingsHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 1 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';

    engine.placeBid(host.id!, 300);
    // Finalize item sale which will finish the 1-item auction
    const completedPromise = new Promise<any>((resolve) => host.on('auction_completed', resolve));
    engine.finalizeItemSale();

    const completedEvt = await completedPromise;
    expect(completedEvt.standings).to.be.an('array').with.lengthOf(1);

    const standing = completedEvt.standings[0];
    expect(standing.playerName).to.equal('StandingsHost');
    expect(standing.rank).to.equal(1);
    // Total team points is revealed accurately on final leaderboard post-match
    expect(standing.totalTeamPoints).to.be.a('number').that.is.above(0);
    // Individual items list must NOT contain powerPoints
    expect(standing.itemsList).to.be.an('array').with.lengthOf(1);
    expect(standing.itemsList[0].itemName).to.be.a('string');
    expect(standing.itemsList[0].price).to.equal(300);
    expect(standing.itemsList[0].powerPoints).to.be.undefined;
  });

  it('6. ProfileManager match history & match details sanitize purchasedItems and omit totalTeamPoints', async () => {
    const host = createClient();
    await waitForConnect(host);

    const res: any = await new Promise((resolve) => {
      host.emit(
        'create_room',
        { username: 'HistoryHost', category: 'cricket', gameMode: 'AUCTION_TEAM_CHALLENGE', itemCount: 1 },
        resolve
      );
    });
    const roomCode = res.roomCode;

    await new Promise((resolve) => host.emit('start_auction', { roomCode }, resolve));
    const engine = roomManager.getAuctionEngine(roomCode)!;
    engine.phase = 'BIDDING';
    engine.placeBid(host.id!, 300);

    const completedPromise = new Promise<any>((resolve) => host.on('auction_completed', resolve));
    engine.finalizeItemSale();
    await completedPromise;

    // Check get_match_history
    const historyRes: any = await new Promise((resolve) => {
      host.emit('get_match_history', { playerId: host.id }, resolve);
    });

    expect(historyRes.success).to.be.true;
    expect(historyRes.matchHistory).to.be.an('array').with.lengthOf.at.least(1);
    const lastMatch = historyRes.matchHistory[0];
    const participant = lastMatch.participants.find((p: any) => p.playerId === host.id);
    expect(participant).to.not.be.undefined;
    expect(participant.totalTeamPoints).to.be.undefined;
    expect(participant.purchasedItems[0].itemName).to.be.a('string');
    expect(participant.purchasedItems[0].powerPoints).to.be.undefined;

    // Check get_match_details
    const detailsRes: any = await new Promise((resolve) => {
      host.emit('get_match_details', { matchId: lastMatch.matchId }, resolve);
    });

    expect(detailsRes.success).to.be.true;
    const detailsParticipant = detailsRes.match.participants.find((p: any) => p.playerId === host.id);
    expect(detailsParticipant.totalTeamPoints).to.be.undefined;
    expect(detailsParticipant.purchasedItems[0].powerPoints).to.be.undefined;
  });

  it('7. get_categories does not leak scoringMethod or provenance', async () => {
    const client = createClient();
    await waitForConnect(client);

    const catRes: any = await new Promise((resolve) => {
      client.emit('get_categories', {}, resolve);
    });

    expect(catRes.success).to.be.true;
    expect(catRes.categories).to.be.an('array').with.lengthOf(11);
    const cricket = catRes.categories.find((c: any) => c.id === 'cricket');
    expect(cricket).to.not.be.undefined;
    expect(cricket.actualCount).to.equal(30);
    expect(cricket.scoringMethod).to.be.undefined;
    expect(cricket.provenance).to.be.undefined;
  });

  it('8. get_player_profile does not leak totalTeamPoints', async () => {
    const client = createClient();
    await waitForConnect(client);

    const profRes: any = await new Promise((resolve) => {
      client.emit('get_player_profile', {}, resolve);
    });

    expect(profRes.success).to.be.true;
    expect(profRes.profile.totalTeamPoints).to.be.undefined;
  });

  it('9. get_leaderboard returns items won without exposing numeric scores', async () => {
    const client = createClient();
    await waitForConnect(client);

    const lbRes: any = await new Promise((resolve) => {
      client.emit('get_leaderboard', { type: 'most_items' }, resolve);
    });

    expect(lbRes.success).to.be.true;
    expect(lbRes.leaderboard).to.be.an('array');
    if (lbRes.leaderboard.length > 0) {
      expect(lbRes.leaderboard[0].detailText).to.not.include('Pts');
      expect(lbRes.leaderboard[0].detailText).to.not.include('Points');
    }
  });
});
