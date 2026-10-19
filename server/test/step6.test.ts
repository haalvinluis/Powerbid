import { expect } from 'chai';
import { io as Client, Socket as ClientSocket } from 'socket.io-client';
import { server, roomManager, startServer } from '../src/index';
import { ProfileManager } from '../src/database/profile_manager';
import { CompletedMatchRecord } from '../src/database/schema';

describe('Step 6: Player Profiles, Match History, Leaderboards & Achievements Tests', function () {
  this.timeout(10000);
  const PORT = 3012;
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
    ProfileManager.getInstance().clearAllData();
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

  it('1. Should validate username rules and enforce uniqueness', () => {
    const pm = ProfileManager.getInstance();

    // 1. Valid unique username
    expect(pm.isUsernameAvailable('HeroPlayer')).to.be.true;

    // 2. Register profile
    const p1 = pm.getOrCreateProfile('user_1', 'HeroPlayer');
    expect(p1.username).to.equal('HeroPlayer');
    expect(p1.avatarText).to.equal('HE');

    // 3. Prevent duplicate username for user_2
    expect(pm.isUsernameAvailable('HeroPlayer', 'user_2')).to.be.false;
    const p2 = pm.getOrCreateProfile('user_2', 'HeroPlayer');
    expect(p2.username).to.not.equal('HeroPlayer'); // Auto-generated alternative name

    // 4. Invalid length / characters
    expect(pm.isUsernameAvailable('ab')).to.be.false; // < 3 chars
    expect(pm.isUsernameAvailable('this_username_is_too_long_for_system')).to.be.false; // > 20 chars
    expect(pm.isUsernameAvailable('Invalid Space')).to.be.false; // Spaces not allowed
  });

  it('2. Should handle win-rate calculations accurately including zero matches and ties', () => {
    const pm = ProfileManager.getInstance();
    const profile = pm.getOrCreateProfile('user_winrate', 'WinRateTest');

    // 0 matches
    expect(pm.calculateWinRate(profile)).to.equal(0);

    // Record 1 win out of 1 match
    const match1: CompletedMatchRecord = {
      matchId: 'm1',
      completedAt: new Date().toISOString(),
      category: 'cricket',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: 'user_winrate',
      winnerName: 'WinRateTest',
      isTie: false,
      participants: [
        {
          playerId: 'user_winrate',
          username: 'WinRateTest',
          rank: 1,
          itemsWon: 2,
          totalTeamPoints: 195,
          remainingBudget: 400,
          purchasedItems: [],
        },
      ],
    };

    pm.recordCompletedMatch(match1);
    expect(profile.matchesPlayed).to.equal(1);
    expect(profile.matchesWon).to.equal(1);
    expect(pm.calculateWinRate(profile)).to.equal(100);

    // Record 1 tie out of 2 matches total (1 win, 1 tie = 50% win rate)
    const match2: CompletedMatchRecord = {
      matchId: 'm2',
      completedAt: new Date().toISOString(),
      category: 'naruto',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: 'user_winrate',
      winnerName: 'WinRateTest',
      isTie: true,
      participants: [
        {
          playerId: 'user_winrate',
          username: 'WinRateTest',
          rank: 1,
          itemsWon: 1,
          totalTeamPoints: 98,
          remainingBudget: 700,
          purchasedItems: [],
        },
      ],
    };

    pm.recordCompletedMatch(match2);
    expect(profile.matchesPlayed).to.equal(2);
    expect(profile.matchesWon).to.equal(1);
    expect(profile.matchesTied).to.equal(1);
    expect(pm.calculateWinRate(profile)).to.equal(50);
  });

  it('3. Should enforce match recording idempotency (prevent duplicate stat inflation)', () => {
    const pm = ProfileManager.getInstance();
    const profile = pm.getOrCreateProfile('user_idempotent', 'IdempotentUser');

    const match: CompletedMatchRecord = {
      matchId: 'match_repeat_99',
      completedAt: new Date().toISOString(),
      category: 'pokemon',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: 'user_idempotent',
      winnerName: 'IdempotentUser',
      isTie: false,
      participants: [
        {
          playerId: 'user_idempotent',
          username: 'IdempotentUser',
          rank: 1,
          itemsWon: 3,
          totalTeamPoints: 260,
          remainingBudget: 200,
          purchasedItems: [],
        },
      ],
    };

    // First recording
    const res1 = pm.recordCompletedMatch(match);
    expect(res1.success).to.be.true;
    expect(res1.isDuplicate).to.be.false;
    expect(profile.matchesPlayed).to.equal(1);
    expect(profile.totalTeamPoints).to.equal(260);

    // Duplicate recording attempt
    const res2 = pm.recordCompletedMatch(match);
    expect(res2.success).to.be.true;
    expect(res2.isDuplicate).to.be.true;
    // Stats must NOT be double-counted
    expect(profile.matchesPlayed).to.equal(1);
    expect(profile.totalTeamPoints).to.equal(260);
  });

  it('4. Should evaluate achievement unlock conditions post-match and prevent duplicate unlocks', () => {
    const pm = ProfileManager.getInstance();
    const profile = pm.getOrCreateProfile('user_achieve', 'Achiever');

    const match: CompletedMatchRecord = {
      matchId: 'm_achieve_1',
      completedAt: new Date().toISOString(),
      category: 'cricket',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: 'user_achieve',
      winnerName: 'Achiever',
      isTie: false,
      participants: [
        {
          playerId: 'user_achieve',
          username: 'Achiever',
          rank: 1,
          itemsWon: 3,
          totalTeamPoints: 260,
          remainingBudget: 200,
          purchasedItems: [],
        },
      ],
    };

    const res = pm.recordCompletedMatch(match);
    const newlyUnlocked = res.newlyUnlocked['user_achieve'] || [];

    // Should unlock first_match, first_victory, and high_scorer (>= 250 pts)
    expect(newlyUnlocked).to.include('first_match');
    expect(newlyUnlocked).to.include('first_victory');
    expect(newlyUnlocked).to.include('high_scorer');

    const achievements = pm.getAchievements('user_achieve');
    const firstMatchAch = achievements.find((a) => a.achievementId === 'first_match');
    expect(firstMatchAch!.isUnlocked).to.be.true;
    expect(firstMatchAch!.progress).to.equal(1);

    // Subsequent match should not re-unlock existing achievements
    const match2: CompletedMatchRecord = {
      ...match,
      matchId: 'm_achieve_2',
    };

    const res2 = pm.recordCompletedMatch(match2);
    const newlyUnlocked2 = res2.newlyUnlocked['user_achieve'] || [];
    expect(newlyUnlocked2).to.not.include('first_match');
    expect(newlyUnlocked2).to.not.include('first_victory');
  });

  it('5. Should handle leaderboards and enforce minimum 5 matches for win-rate leaderboard', () => {
    const pm = ProfileManager.getInstance();

    // Create 2 players: P1 has 1 match (1 win = 100%), P2 has 5 matches (4 wins = 80%)
    const p1 = pm.getOrCreateProfile('p1', 'PlayerOne');
    const p2 = pm.getOrCreateProfile('p2', 'PlayerTwo');

    // Record 1 match for P1
    pm.recordCompletedMatch({
      matchId: 'm_p1',
      completedAt: new Date().toISOString(),
      category: 'cricket',
      gameMode: 'AUCTION_TEAM_CHALLENGE',
      itemCount: 5,
      winnerId: 'p1',
      winnerName: 'PlayerOne',
      isTie: false,
      participants: [{ playerId: 'p1', username: 'PlayerOne', rank: 1, itemsWon: 2, totalTeamPoints: 180, remainingBudget: 400, purchasedItems: [] }],
    });

    // Record 5 matches for P2 (4 wins)
    for (let i = 1; i <= 5; i++) {
      pm.recordCompletedMatch({
        matchId: `m_p2_${i}`,
        completedAt: new Date().toISOString(),
        category: 'naruto',
        gameMode: 'AUCTION_TEAM_CHALLENGE',
        itemCount: 5,
        winnerId: i <= 4 ? 'p2' : 'other',
        winnerName: 'PlayerTwo',
        isTie: false,
        participants: [{ playerId: 'p2', username: 'PlayerTwo', rank: i <= 4 ? 1 : 2, itemsWon: 2, totalTeamPoints: 170, remainingBudget: 400, purchasedItems: [] }],
      });
    }

    // Leaderboard: Most Wins
    const winsLd = pm.getLeaderboard('most_wins');
    expect(winsLd[0].username).to.equal('PlayerTwo'); // 4 wins
    expect(winsLd[0].value).to.equal(4);

    // Leaderboard: Win Rate (requires min 5 completed matches)
    const rateLd = pm.getLeaderboard('win_rate');
    expect(rateLd).to.have.lengthOf(1); // Only P2 qualifies with 5+ matches
    expect(rateLd[0].username).to.equal('PlayerTwo');
    expect(rateLd[0].value).to.equal(80); // 4/5 * 100 = 80%
  });

  it('6. Should handle Socket API requests for profiles, match history, leaderboards, and achievements', async () => {
    const client = createClient();
    await waitForConnect(client);

    // 1. Get Profile
    const profileRes: any = await new Promise((resolve) => {
      client.emit('get_player_profile', {}, resolve);
    });
    expect(profileRes.success).to.be.true;
    expect(profileRes.profile.id).to.equal(client.id);

    // 2. Update Username
    const updateRes: any = await new Promise((resolve) => {
      client.emit('update_username', { username: 'SocketStar_99', avatarText: '⭐' }, resolve);
    });
    expect(updateRes.success).to.be.true;
    expect(updateRes.profile.username).to.equal('SocketStar_99');

    // 3. Get Achievements
    const achRes: any = await new Promise((resolve) => {
      client.emit('get_achievements', {}, resolve);
    });
    expect(achRes.success).to.be.true;
    expect(achRes.achievements).to.have.lengthOf(7);

    // 4. Get Leaderboard
    const ldrRes: any = await new Promise((resolve) => {
      client.emit('get_leaderboard', { type: 'most_wins' }, resolve);
    });
    expect(ldrRes.success).to.be.true;
    expect(ldrRes.leaderboard).to.be.an('array');
  });
});
