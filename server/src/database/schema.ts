export interface CharacterRecord {
  id: string;
  categoryId: string;
  displayName: string;
  name?: string;
  powerPoints: number; // 0 to 100 integer
  scoringMethod: string;
  provenance: string;
  isActive: boolean;
  basePrice: number;
}

export interface CategoryInfo {
  id: string;
  name: string;
  targetCount: number;
  scoringMethod: string;
  provenance: string;
}

export interface PlayerProfile {
  id: string;
  publicPlayerId: string; // Non-sequential unique Player ID (e.g. PB-K8R4X2)
  username: string;
  avatarText: string;
  createdAt: string;
  matchesPlayed: number;
  matchesWon: number;
  matchesTied: number;
  totalCharactersPurchased: number;
  totalTeamPoints: number;
  coinBalance: number; // Persistent virtual coins
  categoriesPlayed: Set<string>;
}

export interface PurchasedItemRecord {
  itemId: string;
  itemName: string;
  price: number;
  powerPoints?: number;
}

export interface MatchParticipantRecord {
  playerId: string;
  username: string;
  rank: number;
  itemsWon: number;
  totalTeamPoints?: number;
  remainingBudget: number;
  purchasedItems: PurchasedItemRecord[];
}

export interface CompletedMatchRecord {
  matchId: string;
  completedAt: string;
  category: string;
  gameMode: 'POWER_COMPARISON' | 'AUCTION_TEAM_CHALLENGE';
  itemCount: number;
  winnerId: string;
  winnerName: string;
  isTie: boolean;
  participants: MatchParticipantRecord[];
}

export interface AchievementDef {
  id: string;
  title: string;
  description: string;
  iconText: string;
  threshold: number;
}

export interface PlayerAchievement {
  playerId: string;
  achievementId: string;
  unlockedAt: string;
}

export interface FriendshipRecord {
  userAId: string;
  userBId: string;
  createdAt: string;
}

export interface FriendRequestRecord {
  requestId: string;
  senderId: string;
  senderUsername: string;
  senderPublicId: string;
  senderAvatarText: string;
  receiverId: string;
  receiverUsername: string;
  receiverPublicId: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED';
  createdAt: string;
  updatedAt: string;
}

export interface RoomInvitationRecord {
  invitationId: string;
  roomCode: string;
  tokenHash: string; // SHA-256 hash of raw invitation token
  hostId: string;
  hostUsername: string;
  hostPublicId: string;
  targetPlayerId?: string; // Optional: set if direct invitation to a specific friend
  targetPublicId?: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED' | 'REVOKED' | 'JOINED';
  type: 'DIRECT_FRIEND' | 'SHAREABLE_LINK';
  maxUses: number;
  usedCount: number;
  expiresAt: number; // Unix epoch ms
  createdAt: number; // Unix epoch ms
}

export interface InAppNotificationRecord {
  id: string;
  recipientId: string;
  type: 'FRIEND_REQUEST' | 'FRIEND_ACCEPTED' | 'ROOM_INVITE';
  title: string;
  message: string;
  data: any;
  isRead: boolean;
  createdAt: string;
}

