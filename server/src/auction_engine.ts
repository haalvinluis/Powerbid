import { Server } from 'socket.io';
import {
  AuctionStateDTO,
  CharacterItemDTO,
  AuctionPhase,
  PlayerDTO,
  StandingsRecordDTO,
  GameMode,
} from '../../shared/socket_events';
import { CharacterDatabase } from './database/db';
import { ProfileManager } from './database/profile_manager';

export const MIN_BID_INCREMENT = 50;
export const ITEM_TIMER_DURATION = 15;

export interface PurchasedItemRecord {
  itemName: string;
  price: number;
  powerPoints: number;
}

export interface InternalPlayer extends PlayerDTO {
  purchasedItemsDetails: PurchasedItemRecord[];
}

export class AuctionEngine {
  public roomCode: string;
  public category: string;
  public gameMode: GameMode;
  public totalItems: number;
  public phase: AuctionPhase = 'LOBBY';
  public currentItemIndex: number = 0;
  public items: CharacterItemDTO[] = [];
  public currentBid: number = 0;
  public leadingBidderId?: string;
  public leadingBidderName?: string;
  public timerSecondsRemaining: number = ITEM_TIMER_DURATION;
  public timerDuration: number = ITEM_TIMER_DURATION;
  public passedPlayerIds: Set<string> = new Set();
  public players: Map<string, InternalPlayer> = new Map();

  private io: Server;
  private timerHandle: NodeJS.Timeout | null = null;
  private isFinalizingSale: boolean = false;

  constructor(
    io: Server,
    roomCode: string,
    category: string,
    gameMode: GameMode,
    totalItems: number,
    initialPlayers: PlayerDTO[],
    timerDuration: number = ITEM_TIMER_DURATION
  ) {
    this.io = io;
    this.roomCode = roomCode;
    this.category = category;
    this.gameMode = gameMode;
    this.totalItems = totalItems;
    this.timerDuration = timerDuration;
    this.timerSecondsRemaining = timerDuration;

    // Fetch unique records from verified CharacterDatabase
    const dbRecords = CharacterDatabase.getInstance().getCharacterRecords(category, totalItems);
    this.items = dbRecords.map((r) => ({
      id: r.id,
      categoryId: r.categoryId,
      displayName: r.displayName,
      name: r.displayName,
      powerPoints: r.powerPoints,
      scoringMethod: r.scoringMethod,
      provenance: r.provenance,
      isActive: r.isActive,
      basePrice: r.basePrice,
    }));

    initialPlayers.forEach((p) => {
      this.players.set(p.id, {
        ...p,
        purchasedItemsDetails: [],
      });
    });
  }

  public get currentItem(): CharacterItemDTO | undefined {
    return this.items[this.currentItemIndex];
  }

  public toClientItem(item?: CharacterItemDTO): CharacterItemDTO | undefined {
    if (!item) return undefined;
    return {
      id: item.id,
      categoryId: item.categoryId,
      category: item.category,
      displayName: item.displayName,
      name: item.name || item.displayName,
      basePrice: item.basePrice,
      isActive: item.isActive,
    };
  }

  public get minNextBid(): number {
    if (!this.currentItem) return 0;
    if (this.currentBid === 0) {
      return this.currentItem.basePrice;
    }
    return this.currentBid + MIN_BID_INCREMENT;
  }

  public broadcastAuctionState(): void {
    const stateDTO = this.getAuctionStateDTO();
    this.io.to(this.roomCode).emit('auction_state_update', stateDTO);
  }

  public startAuction(hostSocketId: string): void {
    if (this.phase !== 'LOBBY') {
      throw new Error('Auction is already in progress.');
    }

    const host = this.players.get(hostSocketId);
    if (!host || !host.isHost) {
      throw new Error('Only the room host can start the auction.');
    }

    this.phase = 'ITEM_ANNOUNCED';
    this.currentItemIndex = 0;
    this.currentBid = 0;
    this.leadingBidderId = undefined;
    this.leadingBidderName = undefined;
    this.passedPlayerIds.clear();

    const stateDTO = this.getAuctionStateDTO();
    this.io.to(this.roomCode).emit('auction_started', { roomCode: this.roomCode, roomState: stateDTO });
    this.io.to(this.roomCode).emit('item_announced', {
      roomCode: this.roomCode,
      currentItem: this.toClientItem(this.currentItem),
      itemIndex: this.currentItemIndex + 1,
      totalItems: this.totalItems,
    });

    setTimeout(() => {
      if (this.phase === 'ITEM_ANNOUNCED') {
        this.startBiddingPhase();
      }
    }, 200);
  }

  public startBiddingPhase(): void {
    this.phase = 'BIDDING';
    this.timerSecondsRemaining = this.timerDuration;
    this.isFinalizingSale = false;
    this.passedPlayerIds.clear();
    this.currentBid = 0;
    this.leadingBidderId = undefined;
    this.leadingBidderName = undefined;

    this.broadcastAuctionState();

    if (this.gameMode === 'POWER_COMPARISON') {
      // In Mode A (Power Comparison), immediately compare character power after 3 seconds
      setTimeout(() => {
        if (this.phase === 'BIDDING') {
          this.finalizePowerComparison();
        }
      }, 3000);
    } else {
      // In Mode B (Auction Team Challenge), run bidding timer
      this.resetTimer();
    }
  }

  private resetTimer(): void {
    if (this.timerHandle) {
      clearInterval(this.timerHandle);
      this.timerHandle = null;
    }

    this.timerSecondsRemaining = this.timerDuration;

    this.timerHandle = setInterval(() => {
      this.timerSecondsRemaining--;
      this.broadcastAuctionState();

      if (this.timerSecondsRemaining <= 0) {
        this.stopTimer();
        this.finalizeItemSale();
      }
    }, 1000);
  }

  public stopTimer(): void {
    if (this.timerHandle) {
      clearInterval(this.timerHandle);
      this.timerHandle = null;
    }
  }

  public placeBid(
    socketId: string,
    amount: number
  ): { success: boolean; currentBid: number; bidderId: string; bidderName: string } {
    if (!Number.isInteger(amount) || amount <= 0 || !Number.isFinite(amount)) {
      throw new Error('Invalid bid amount. Must be a positive integer.');
    }

    if (this.gameMode === 'POWER_COMPARISON') {
      throw new Error('Bidding is not active in Mode A: Character Power Comparison.');
    }

    if (this.phase !== 'BIDDING') {
      throw new Error('Bidding is not open for this item.');
    }

    if (this.timerSecondsRemaining <= 0) {
      throw new Error('Timer has expired for this item.');
    }

    const player = this.players.get(socketId);
    if (!player) {
      throw new Error('Participant not found in room.');
    }

    if (this.passedPlayerIds.has(socketId)) {
      throw new Error('You have passed on this item and cannot bid again.');
    }

    const requiredMin = this.minNextBid;
    if (amount < requiredMin) {
      throw new Error(`Bid amount \$${amount} is below required minimum of \$${requiredMin}.`);
    }

    if (player.budget < amount) {
      throw new Error(`Insufficient budget. You have \$${player.budget} remaining.`);
    }

    this.currentBid = amount;
    this.leadingBidderId = socketId;
    this.leadingBidderName = player.name;

    this.resetTimer();

    const result = {
      success: true,
      currentBid: this.currentBid,
      bidderId: socketId,
      bidderName: player.name,
    };

    this.io.to(this.roomCode).emit('bid_accepted', {
      roomCode: this.roomCode,
      ...result,
      roomState: this.getAuctionStateDTO(),
    });

    return result;
  }

  public passItem(socketId: string): { success: boolean } {
    if (this.phase !== 'BIDDING') {
      throw new Error('Bidding is not open for this item.');
    }

    const player = this.players.get(socketId);
    if (!player) {
      throw new Error('Participant not found in room.');
    }

    this.passedPlayerIds.add(socketId);

    this.io.to(this.roomCode).emit('player_passed', {
      roomCode: this.roomCode,
      playerId: socketId,
      playerName: player.name,
      roomState: this.getAuctionStateDTO(),
    });

    this.checkAutoFinalize();

    return { success: true };
  }

  private checkAutoFinalize(): void {
    const activePlayers = Array.from(this.players.values());
    const unpassedCount = activePlayers.filter((p) => !this.passedPlayerIds.has(p.id)).length;

    if (unpassedCount === 0 || (this.leadingBidderId && unpassedCount <= 1)) {
      this.stopTimer();
      this.finalizeItemSale();
    }
  }

  /**
   * Mode A: Direct Character Power Comparison
   */
  public finalizePowerComparison(): void {
    if (this.isFinalizingSale) return;
    this.isFinalizingSale = true;
    this.stopTimer();

    const item = this.currentItem;
    if (!item) return;

    this.phase = 'SOLD';
    console.log(`[Mode A Power Comparison] Item: ${item.displayName}`);

    this.io.to(this.roomCode).emit('item_sold', {
      roomCode: this.roomCode,
      item: this.toClientItem(item),
      winnerId: 'SERVER',
      winnerName: item.displayName,
      price: 0,
      roomState: this.getAuctionStateDTO(),
    });

    setTimeout(() => {
      this.advanceToNextItem();
    }, 2500);
  }

  /**
   * Mode B: Finalize Item Sale & Deduct Budget Exactly Once
   */
  public finalizeItemSale(): void {
    if (this.isFinalizingSale) return;
    this.isFinalizingSale = true;
    this.stopTimer();

    const item = this.currentItem;
    if (!item) return;

    if (this.leadingBidderId && this.players.has(this.leadingBidderId)) {
      this.phase = 'SOLD';
      const winner = this.players.get(this.leadingBidderId)!;

      // Deduct budget EXACTLY ONCE
      winner.budget -= this.currentBid;
      winner.acquiredItems.push(item.displayName);
      winner.purchasedItemsDetails.push({
        itemName: item.displayName,
        price: this.currentBid,
        powerPoints: item.powerPoints ?? 0,
      });

      console.log(
        `[Item SOLD] ${item.displayName} to ${winner.name} for \$${this.currentBid}`
      );

      this.io.to(this.roomCode).emit('item_sold', {
        roomCode: this.roomCode,
        item: this.toClientItem(item),
        winnerId: winner.id,
        winnerName: winner.name,
        price: this.currentBid,
        roomState: this.getAuctionStateDTO(),
      });
    } else {
      this.phase = 'UNSOLD';
      console.log(`[Item UNSOLD] ${item.displayName} received no bids`);

      this.io.to(this.roomCode).emit('item_unsold', {
        roomCode: this.roomCode,
        item: this.toClientItem(item),
        roomState: this.getAuctionStateDTO(),
      });
    }

    setTimeout(() => {
      this.advanceToNextItem();
    }, 2500);
  }

  private advanceToNextItem(): void {
    this.currentItemIndex++;

    if (this.currentItemIndex < this.totalItems && this.currentItemIndex < this.items.length) {
      this.phase = 'ITEM_ANNOUNCED';
      this.currentBid = 0;
      this.leadingBidderId = undefined;
      this.leadingBidderName = undefined;
      this.passedPlayerIds.clear();

      this.io.to(this.roomCode).emit('item_announced', {
        roomCode: this.roomCode,
        currentItem: this.toClientItem(this.currentItem),
        itemIndex: this.currentItemIndex + 1,
        totalItems: this.totalItems,
      });

      setTimeout(() => {
        if (this.phase === 'ITEM_ANNOUNCED') {
          this.startBiddingPhase();
        }
      }, 200);
    } else {
      this.phase = 'COMPLETED';
      this.stopTimer();

      const rankedList = this.getRankedPlayersInternal();
      const standings = this.calculateFinalStandings();

      // Check for tie using private server-side calculation (top 2 players have identical team points, items won, and budget)
      const isTie =
        rankedList.length > 1 &&
        rankedList[0].totalTeamPoints === rankedList[1].totalTeamPoints &&
        rankedList[0].player.acquiredItems.length === rankedList[1].player.acquiredItems.length &&
        rankedList[0].player.budget === rankedList[1].player.budget;

      const winnerId = standings.length > 0 ? standings[0].playerId : '';
      const winnerName = standings.length > 0 ? standings[0].playerName : 'None';

      const matchRecord = {
        matchId: `match_${this.roomCode}_${Date.now()}`,
        completedAt: new Date().toISOString(),
        category: this.category,
        gameMode: this.gameMode,
        itemCount: this.totalItems,
        winnerId,
        winnerName,
        isTie,
        participants: standings.map((s, idx) => ({
          playerId: s.playerId,
          username: s.playerName,
          rank: s.rank,
          itemsWon: s.itemsWon,
          totalTeamPoints: rankedList[idx]?.totalTeamPoints,
          remainingBudget: s.remainingBudget,
          purchasedItems: s.itemsList.map((item) => ({
            itemId: item.itemName,
            itemName: item.itemName,
            price: item.price,
          })),
        })),
      };

      const recordRes = ProfileManager.getInstance().recordCompletedMatch(matchRecord);

      console.log(`[Auction COMPLETED] Mode: ${this.gameMode}, Room: ${this.roomCode}, Winner: ${winnerName}`);

      this.io.to(this.roomCode).emit('auction_completed', {
        roomCode: this.roomCode,
        gameMode: this.gameMode,
        standings,
        roomState: this.getAuctionStateDTO(),
        newUnlockedAchievements: recordRes.newlyUnlocked,
      });
    }
  }

  /**
   * Deterministic Final Standings Calculation:
   * Mode B (Auction Team Challenge):
   * 1. Total team power points sum (descending)
   * 2. Total items won (descending)
   * 3. Remaining budget (descending)
   */
  private getRankedPlayersInternal(): { player: InternalPlayer; totalTeamPoints: number }[] {
    const list = Array.from(this.players.values()).map((p) => {
      const totalTeamPoints = p.purchasedItemsDetails.reduce(
        (sum, item) => sum + item.powerPoints,
        0
      );
      return {
        player: p,
        totalTeamPoints,
      };
    });

    list.sort((a, b) => {
      // 1. Total team points sum
      const cmpPoints = b.totalTeamPoints - a.totalTeamPoints;
      if (cmpPoints !== 0) return cmpPoints;

      // 2. Items won count
      const cmpItems = b.player.acquiredItems.length - a.player.acquiredItems.length;
      if (cmpItems !== 0) return cmpItems;

      // 3. Remaining budget
      return b.player.budget - a.player.budget;
    });

    return list;
  }

  public calculateFinalStandings(): StandingsRecordDTO[] {
    const list = this.getRankedPlayersInternal();

    return list.map((item, idx) => ({
      rank: idx + 1,
      playerId: item.player.id,
      playerName: item.player.name,
      itemsWon: item.player.acquiredItems.length,
      itemsList: item.player.purchasedItemsDetails.map((d) => ({
        itemName: d.itemName,
        price: d.price,
      })),
      totalTeamPoints: item.totalTeamPoints,
      remainingBudget: item.player.budget,
    }));
  }

  public updatePlayers(updatedPlayersList: PlayerDTO[]): void {
    const newPlayerMap = new Map<string, InternalPlayer>();
    updatedPlayersList.forEach((p) => {
      const existing = this.players.get(p.id);
      newPlayerMap.set(p.id, {
        ...p,
        budget: existing ? existing.budget : p.budget,
        acquiredItems: existing ? existing.acquiredItems : p.acquiredItems,
        purchasedItemsDetails: existing ? existing.purchasedItemsDetails : [],
      });
    });
    this.players = newPlayerMap;
  }

  public handlePlayerDisconnect(socketId: string): void {
    this.passedPlayerIds.add(socketId);
    if (this.phase === 'BIDDING') {
      this.checkAutoFinalize();
    }
  }

  public getAuctionStateDTO(): AuctionStateDTO {
    return {
      roomCode: this.roomCode,
      gameMode: this.gameMode,
      phase: this.phase,
      currentItemIndex: this.currentItemIndex,
      totalItems: this.totalItems,
      currentItem: this.toClientItem(this.currentItem),
      currentBid: this.currentBid,
      minNextBid: this.minNextBid,
      leadingBidderId: this.leadingBidderId,
      leadingBidderName: this.leadingBidderName,
      timerDuration: this.timerDuration,
      timerSecondsRemaining: this.timerSecondsRemaining,
      passedPlayerIds: Array.from(this.passedPlayerIds),
      players: Array.from(this.players.values()).map((p) => ({
        id: p.id,
        name: p.name,
        isHost: p.isHost,
        isReady: p.isReady,
        budget: p.budget,
        acquiredItems: p.acquiredItems,
      })),
    };
  }

  public destroy(): void {
    this.stopTimer();
  }
}
