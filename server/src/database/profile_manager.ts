import { randomBytes } from 'crypto';
import {
  PlayerProfile,
  CompletedMatchRecord,
  AchievementDef,
  PlayerAchievement,
} from './schema';
import {
  PlayerProfileDTO,
  MatchRecordDTO,
  LeaderboardEntryDTO,
  AchievementDefDTO,
  PlayerAchievementDTO,
  CoinTransactionDTO,
} from '../../../shared/socket_events';
import { DatabasePool } from './pg_pool';

export const ACHIEVEMENTS_CATALOG: AchievementDef[] = [
  {
    id: 'first_match',
    title: 'First Match',
    description: 'Complete your first online multiplayer auction match.',
    iconText: '🎮',
    threshold: 1,
  },
  {
    id: 'first_victory',
    title: 'First Victory',
    description: 'Win your first online auction match.',
    iconText: '🏆',
    threshold: 1,
  },
  {
    id: 'veteran',
    title: 'Veteran Player',
    description: 'Complete 10 online auction matches.',
    iconText: '🎖️',
    threshold: 10,
  },
  {
    id: 'five_victories',
    title: 'Five Victories',
    description: 'Win 5 online auction matches.',
    iconText: '👑',
    threshold: 5,
  },
  {
    id: 'collector',
    title: 'Collector',
    description: 'Purchase 10 characters total across completed matches.',
    iconText: '📦',
    threshold: 10,
  },
  {
    id: 'high_scorer',
    title: 'High Scorer',
    description: 'Accumulate 250 total team power points.',
    iconText: '⚡',
    threshold: 250,
  },
  {
    id: 'explorer',
    title: 'Category Explorer',
    description: 'Complete matches across 3 different categories.',
    iconText: '🧭',
    threshold: 3,
  },
];

export class ProfileManager {
  private static instance: ProfileManager;

  private profilesMap: Map<string, PlayerProfile> = new Map();
  private publicPlayerIdToIdMap: Map<string, string> = new Map();
  private usernameToIdMap: Map<string, string> = new Map();
  private completedMatches: CompletedMatchRecord[] = [];
  private matchesMap: Map<string, CompletedMatchRecord> = new Map();
  private processedMatchIds: Set<string> = new Set();
  private playerAchievementsMap: Map<string, Map<string, PlayerAchievement>> = new Map();
  private coinTransactions: CoinTransactionDTO[] = [];
  private processedCoinMatchIds: Set<string> = new Set();

  private constructor() {}

  public static getInstance(): ProfileManager {
    if (!ProfileManager.instance) {
      ProfileManager.instance = new ProfileManager();
    }
    return ProfileManager.instance;
  }

  /**
   * Generates a permanent, unique, non-sequential public Player ID (e.g., PB-A7K9X2).
   * Excludes easily confused characters (0, O, 1, I).
   */
  public generatePublicPlayerId(): string {
    const charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    let id = '';
    do {
      id = 'PB-';
      const bytes = randomBytes(6);
      for (let i = 0; i < 6; i++) {
        id += charset[bytes[i] % charset.length];
      }
    } while (this.publicPlayerIdToIdMap.has(id));
    return id;
  }

  public getOrCreateProfile(playerId: string, requestedUsername?: string): PlayerProfile {
    let profile = this.profilesMap.get(playerId);
    if (profile) {
      return profile;
    }

    let username = requestedUsername ? requestedUsername.trim() : '';
    if (!username || !this.isUsernameAvailable(username, playerId)) {
      const baseName = username ? username.replace(/[^a-zA-Z0-9_]/g, '') : `Player_${playerId.replace(/[^a-zA-Z0-9]/g, '').substring(0, 6) || randomBytes(3).toString('hex').toUpperCase()}`;
      let candidate = baseName.length >= 3 ? baseName : `Player_${randomBytes(3).toString('hex').toUpperCase()}`;
      let count = 1;
      while (this.usernameToIdMap.has(candidate.toLowerCase())) {
        candidate = `${baseName}_${count++}`;
      }
      username = candidate;
    }

    const avatarText = username.length >= 2 ? username.substring(0, 2).toUpperCase() : '⚡';
    const publicPlayerId = this.generatePublicPlayerId();

    profile = {
      id: playerId,
      publicPlayerId,
      username,
      avatarText,
      createdAt: new Date().toISOString(),
      matchesPlayed: 0,
      matchesWon: 0,
      matchesTied: 0,
      totalCharactersPurchased: 0,
      totalTeamPoints: 0,
      coinBalance: 500,
      categoriesPlayed: new Set<string>(),
    };

    this.profilesMap.set(playerId, profile);
    this.publicPlayerIdToIdMap.set(publicPlayerId, playerId);
    this.usernameToIdMap.set(username.toLowerCase(), playerId);
    return profile;
  }

  public isUsernameAvailable(username: string, currentUserId?: string): boolean {
    const clean = username.trim();
    if (clean.length < 3 || clean.length > 20) return false;
    if (!/^[a-zA-Z0-9_]+$/.test(clean)) return false;

    const existingId = this.usernameToIdMap.get(clean.toLowerCase());
    if (!existingId) return true;
    return existingId === currentUserId;
  }

  public updateUsername(
    playerId: string,
    newUsername: string,
    avatarText?: string
  ): { success: boolean; error?: string; profile?: PlayerProfile } {
    const profile = this.getOrCreateProfile(playerId);
    const clean = newUsername.trim();

    if (!this.isUsernameAvailable(clean, playerId)) {
      return {
        success: false,
        error: `Username "${clean}" is invalid or already taken by another player.`,
      };
    }

    // Unset old username mapping
    this.usernameToIdMap.delete(profile.username.toLowerCase());

    profile.username = clean;
    if (avatarText && avatarText.trim().length > 0) {
      profile.avatarText = avatarText.trim().substring(0, 4);
    } else if (clean.length >= 2) {
      profile.avatarText = clean.substring(0, 2).toUpperCase();
    }

    this.usernameToIdMap.set(clean.toLowerCase(), playerId);
    return { success: true, profile };
  }

  public calculateWinRate(profile: PlayerProfile): number {
    if (profile.matchesPlayed === 0) return 0;
    const rate = (profile.matchesWon / profile.matchesPlayed) * 100;
    return Number(rate.toFixed(1));
  }

  public getProfileDTO(playerId: string): PlayerProfileDTO {
    const profile = this.getOrCreateProfile(playerId);
    const achievements = this.getAchievements(playerId);
    const unlockedCount = achievements.filter((a) => a.isUnlocked).length;

    return {
      id: profile.id,
      publicPlayerId: profile.publicPlayerId,
      playerId: profile.publicPlayerId,
      username: profile.username,
      avatarText: profile.avatarText,
      createdAt: profile.createdAt,
      matchesPlayed: profile.matchesPlayed,
      matchesWon: profile.matchesWon,
      matchesTied: profile.matchesTied,
      winRate: this.calculateWinRate(profile),
      totalCharactersPurchased: profile.totalCharactersPurchased,
      coinBalance: profile.coinBalance ?? 500,
      achievementsUnlockedCount: unlockedCount,
      totalAchievementsCount: ACHIEVEMENTS_CATALOG.length,
    };
  }

  public getProfileByPublicId(publicId: string): PlayerProfile | undefined {
    const internalId = this.publicPlayerIdToIdMap.get(publicId.trim().toUpperCase());
    if (!internalId) return undefined;
    return this.profilesMap.get(internalId);
  }

  public getProfileById(playerId: string): PlayerProfile | undefined {
    return this.profilesMap.get(playerId);
  }

  public getPublicPlayerId(playerId: string): string {
    const profile = this.getOrCreateProfile(playerId);
    return profile.publicPlayerId;
  }

  /**
   * Idempotently records a completed match and updates participant stats & achievements strictly once.
   */
  public recordCompletedMatch(match: CompletedMatchRecord): {
    success: boolean;
    isDuplicate: boolean;
    newlyUnlocked: Record<string, string[]>;
  } {
    if (this.processedMatchIds.has(match.matchId)) {
      console.log(`[ProfileManager] Match ${match.matchId} already processed (idempotent skip).`);
      return { success: true, isDuplicate: true, newlyUnlocked: {} };
    }

    this.processedMatchIds.add(match.matchId);
    this.completedMatches.unshift(match);
    this.matchesMap.set(match.matchId, match);

    const newlyUnlockedMap: Record<string, string[]> = {};

    for (const participant of match.participants) {
      const profile = this.getOrCreateProfile(participant.playerId, participant.username);

      profile.matchesPlayed += 1;
      if (match.isTie && participant.rank === 1) {
        profile.matchesTied += 1;
      } else if (participant.rank === 1) {
        profile.matchesWon += 1;
      }

      profile.totalCharactersPurchased += participant.itemsWon;
      profile.totalTeamPoints += participant.totalTeamPoints ?? 0;
      profile.categoriesPlayed.add(match.category.toLowerCase());

      // Evaluate achievements post-match
      const unlockedList = this.evaluateAchievements(profile.id);
      if (unlockedList.length > 0) {
        newlyUnlockedMap[profile.id] = unlockedList;
      }
    }

    // Award virtual coins idempotently for completed match
    this.awardMatchCoins(match.matchId, match.winnerId, match.participants);

    return { success: true, isDuplicate: false, newlyUnlocked: newlyUnlockedMap };
  }

  /**
   * Idempotently awards virtual coins for a completed match.
   * Winner receives 150 coins, runner-up receives 75 coins, and finishing participants receive 25 coins.
   */
  public async awardMatchCoins(
    matchId: string,
    winnerId: string,
    participants: { playerId: string; rank: number; username?: string }[]
  ): Promise<Map<string, { amount: number; balanceAfter: number }>> {
    const rewardsMap = new Map<string, { amount: number; balanceAfter: number }>();
    if (this.processedCoinMatchIds.has(matchId)) {
      return rewardsMap;
    }
    this.processedCoinMatchIds.add(matchId);

    const db = DatabasePool.getInstance();

    for (const p of participants) {
      const profile = this.getOrCreateProfile(p.playerId, p.username);
      let amount = 25; // Participation award for completed match
      let reason = 'MATCH_PARTICIPATION_REWARD';

      if (p.rank === 1) {
        amount = 150; // Winner reward
        reason = 'MATCH_WIN_REWARD';
      } else if (p.rank === 2) {
        amount = 75; // Runner-up
        reason = 'MATCH_RUNNER_UP_REWARD';
      }

      profile.coinBalance = (profile.coinBalance ?? 500) + amount;
      const txId = 'ctx_' + randomBytes(16).toString('hex');
      const tx: CoinTransactionDTO = {
        id: txId,
        playerId: p.playerId,
        amount,
        balanceAfter: profile.coinBalance,
        reason,
        referenceId: matchId,
        createdAt: new Date().toISOString(),
      };

      this.coinTransactions.unshift(tx);
      rewardsMap.set(p.playerId, { amount, balanceAfter: profile.coinBalance });

      if (db.isDatabaseConnected) {
        try {
          await db.query(
            `INSERT INTO player_profiles (id, public_player_id, username, avatar_text, coin_balance, created_at)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (id) DO UPDATE SET coin_balance = $5`,
            [profile.id, profile.publicPlayerId, profile.username, profile.avatarText, profile.coinBalance, new Date().toISOString()]
          );
          await db.query(
            `INSERT INTO coin_transactions (id, player_id, amount, balance_after, reason, reference_id, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (player_id, reference_id, reason) DO NOTHING`,
            [txId, p.playerId, amount, profile.coinBalance, reason, matchId, tx.createdAt]
          );
        } catch (err: any) {
          console.error(`[ProfileManager] Database error saving coin transaction for ${p.playerId}:`, err.message);
        }
      }
    }

    return rewardsMap;
  }

  /**
   * Retrieves coin transaction history for a player.
   */
  public getCoinTransactions(playerId: string, limit: number = 20): CoinTransactionDTO[] {
    return this.coinTransactions
      .filter((tx) => tx.playerId === playerId)
      .slice(0, limit);
  }

  private evaluateAchievements(playerId: string): string[] {
    const profile = this.getOrCreateProfile(playerId);
    let playerUnlocks = this.playerAchievementsMap.get(playerId);
    if (!playerUnlocks) {
      playerUnlocks = new Map<string, PlayerAchievement>();
      this.playerAchievementsMap.set(playerId, playerUnlocks);
    }

    const newlyUnlockedIds: string[] = [];

    for (const achDef of ACHIEVEMENTS_CATALOG) {
      if (playerUnlocks.has(achDef.id)) continue; // Already unlocked

      let isUnlocked = false;

      switch (achDef.id) {
        case 'first_match':
          isUnlocked = profile.matchesPlayed >= 1;
          break;
        case 'first_victory':
          isUnlocked = profile.matchesWon >= 1;
          break;
        case 'veteran':
          isUnlocked = profile.matchesPlayed >= 10;
          break;
        case 'five_victories':
          isUnlocked = profile.matchesWon >= 5;
          break;
        case 'collector':
          isUnlocked = profile.totalCharactersPurchased >= 10;
          break;
        case 'high_scorer':
          isUnlocked = profile.totalTeamPoints >= 250;
          break;
        case 'explorer':
          isUnlocked = profile.categoriesPlayed.size >= 3;
          break;
      }

      if (isUnlocked) {
        const unlockRecord: PlayerAchievement = {
          playerId,
          achievementId: achDef.id,
          unlockedAt: new Date().toISOString(),
        };
        playerUnlocks.set(achDef.id, unlockRecord);
        newlyUnlockedIds.push(achDef.id);
      }
    }

    return newlyUnlockedIds;
  }

  public getAchievements(playerId: string): PlayerAchievementDTO[] {
    const profile = this.getOrCreateProfile(playerId);
    const playerUnlocks = this.playerAchievementsMap.get(playerId) || new Map();

    return ACHIEVEMENTS_CATALOG.map((def) => {
      const unlockRecord = playerUnlocks.get(def.id);
      const isUnlocked = unlockRecord !== undefined;

      let progress = 0;
      switch (def.id) {
        case 'first_match':
        case 'veteran':
          progress = Math.min(profile.matchesPlayed, def.threshold);
          break;
        case 'first_victory':
        case 'five_victories':
          progress = Math.min(profile.matchesWon, def.threshold);
          break;
        case 'collector':
          progress = Math.min(profile.totalCharactersPurchased, def.threshold);
          break;
        case 'high_scorer':
          progress = Math.min(profile.totalTeamPoints, def.threshold);
          break;
        case 'explorer':
          progress = Math.min(profile.categoriesPlayed.size, def.threshold);
          break;
      }

      return {
        achievementId: def.id,
        title: def.title,
        description: def.description,
        iconText: def.iconText,
        threshold: def.threshold,
        isUnlocked,
        unlockedAt: unlockRecord?.unlockedAt,
        progress,
      };
    });
  }

  public getMatchHistory(playerId?: string, limit: number = 20): MatchRecordDTO[] {
    let source = this.completedMatches;

    if (playerId) {
      source = source.filter((m) =>
        m.participants.some((p) => p.playerId === playerId)
      );
    }

    return source.slice(0, limit).map((m) => ({
      matchId: m.matchId,
      completedAt: m.completedAt,
      category: m.category,
      gameMode: m.gameMode,
      itemCount: m.itemCount,
      winnerId: m.winnerId,
      winnerName: m.winnerName,
      isTie: m.isTie,
      participants: m.participants.map((p) => ({
        playerId: p.playerId,
        username: p.username,
        rank: p.rank,
        itemsWon: p.itemsWon,
        remainingBudget: p.remainingBudget,
        purchasedItems: p.purchasedItems.map((item) => ({
          itemId: item.itemId,
          itemName: item.itemName,
          price: item.price,
        })),
      })),
    }));
  }

  public getMatchDetails(matchId: string): MatchRecordDTO | undefined {
    const m = this.matchesMap.get(matchId);
    if (!m) return undefined;

    return {
      matchId: m.matchId,
      completedAt: m.completedAt,
      category: m.category,
      gameMode: m.gameMode,
      itemCount: m.itemCount,
      winnerId: m.winnerId,
      winnerName: m.winnerName,
      isTie: m.isTie,
      participants: m.participants.map((p) => ({
        playerId: p.playerId,
        username: p.username,
        rank: p.rank,
        itemsWon: p.itemsWon,
        remainingBudget: p.remainingBudget,
        purchasedItems: p.purchasedItems.map((item) => ({
          itemId: item.itemId,
          itemName: item.itemName,
          price: item.price,
        })),
      })),
    };
  }

  public getLeaderboard(
    type: 'most_wins' | 'win_rate' | 'total_points' | 'most_matches' | 'most_items',
    limit: number = 10
  ): LeaderboardEntryDTO[] {
    const allProfiles = Array.from(this.profilesMap.values());

    let filtered = allProfiles;

    if (type === 'win_rate') {
      // Require a minimum of 5 completed matches for Win Rate leaderboard
      filtered = filtered.filter((p) => p.matchesPlayed >= 5);
    }

    // Sort descending by target stat with tie-breaking rules
    filtered.sort((a, b) => {
      let valA = 0;
      let valB = 0;

      switch (type) {
        case 'most_wins':
          valA = a.matchesWon;
          valB = b.matchesWon;
          break;
        case 'win_rate':
          valA = this.calculateWinRate(a);
          valB = this.calculateWinRate(b);
          break;
        case 'most_items':
        case 'total_points':
          valA = a.totalCharactersPurchased;
          valB = b.totalCharactersPurchased;
          break;
        case 'most_matches':
          valA = a.matchesPlayed;
          valB = b.matchesPlayed;
          break;
      }

      if (valB !== valA) return valB - valA;
      // Secondary tie-breaker: Total Wins -> Total Matches -> Username
      if (b.matchesWon !== a.matchesWon) return b.matchesWon - a.matchesWon;
      return a.username.localeCompare(b.username);
    });

    return filtered.slice(0, limit).map((p, idx) => {
      let val = 0;
      let detailText = '';

      switch (type) {
        case 'most_wins':
          val = p.matchesWon;
          detailText = `${p.matchesWon} Wins (${p.matchesPlayed} Matches)`;
          break;
        case 'win_rate':
          val = this.calculateWinRate(p);
          detailText = `${val}% Win Rate (${p.matchesWon}W / ${p.matchesPlayed}M)`;
          break;
        case 'most_items':
        case 'total_points':
          val = p.totalCharactersPurchased;
          detailText = `${p.totalCharactersPurchased} Items Won`;
          break;
        case 'most_matches':
          val = p.matchesPlayed;
          detailText = `${p.matchesPlayed} Matches Played`;
          break;
      }

      return {
        rank: idx + 1,
        playerId: p.id,
        username: p.username,
        avatarText: p.avatarText,
        value: val,
        detailText,
      };
    });
  }

  public clearAllData(): void {
    this.profilesMap.clear();
    this.usernameToIdMap.clear();
    this.completedMatches = [];
    this.matchesMap.clear();
    this.processedMatchIds.clear();
    this.playerAchievementsMap.clear();
    this.coinTransactions = [];
    this.processedCoinMatchIds.clear();
  }
}
