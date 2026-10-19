import { randomBytes, randomUUID, createHash } from 'crypto';
import {
  FriendshipRecord,
  FriendRequestRecord,
  RoomInvitationRecord,
  InAppNotificationRecord,
} from './database/schema';
import { ProfileManager } from './database/profile_manager';
import {
  PublicPlayerSearchDTO,
  FriendDTO,
  FriendRequestDTO,
  RoomInvitationDTO,
  RoomPreviewDTO,
  InAppNotificationDTO,
} from '../../shared/socket_events';

export class FriendsManager {
  private static instance: FriendsManager;

  // Friendships: user internal ID -> Set of friend internal IDs
  private userFriendsMap: Map<string, Set<string>> = new Map();
  private friendshipsList: FriendshipRecord[] = [];

  // Friend Requests: requestId -> record
  private requestsMap: Map<string, FriendRequestRecord> = new Map();
  // Sender internal ID -> Set of requestIds
  private userOutgoingRequestsMap: Map<string, Set<string>> = new Map();
  // Receiver internal ID -> Set of requestIds
  private userIncomingRequestsMap: Map<string, Set<string>> = new Map();

  // Room Invitations: invitationId -> record
  private invitationsMap: Map<string, RoomInvitationRecord> = new Map();
  // tokenHash -> invitation record
  private tokenHashToInvitationMap: Map<string, RoomInvitationRecord> = new Map();
  // roomCode -> Set of invitationIds
  private roomInvitationsMap: Map<string, Set<string>> = new Map();

  // In-App Notifications: recipient internal ID -> Array of records
  private notificationsMap: Map<string, InAppNotificationRecord[]> = new Map();

  // Active socket tracking: userId -> socketId (and socketId -> userId)
  private userToSocketMap: Map<string, string> = new Map();
  private socketToUserMap: Map<string, string> = new Map();

  private constructor() {}

  public static getInstance(): FriendsManager {
    if (!FriendsManager.instance) {
      FriendsManager.instance = new FriendsManager();
    }
    return FriendsManager.instance;
  }

  // ==================== Socket & Presence Tracking ====================

  public registerUserSocket(userId: string, socketId: string): void {
    this.userToSocketMap.set(userId, socketId);
    this.socketToUserMap.set(socketId, userId);
  }

  public unregisterUserSocket(socketId: string): void {
    const userId = this.socketToUserMap.get(socketId);
    if (userId) {
      if (this.userToSocketMap.get(userId) === socketId) {
        this.userToSocketMap.delete(userId);
      }
      this.socketToUserMap.delete(socketId);
    }
  }

  public isUserOnline(userId: string): boolean {
    return this.userToSocketMap.has(userId);
  }

  public getSocketIdForUser(userId: string): string | undefined {
    return this.userToSocketMap.get(userId);
  }

  // ==================== Friend Search ====================

  public searchPlayerByPublicId(
    searcherId: string,
    queryPlayerId: string
  ): { success: boolean; error?: string; player?: PublicPlayerSearchDTO } {
    if (!queryPlayerId || typeof queryPlayerId !== 'string') {
      return { success: false, error: 'Player ID is required.' };
    }

    const cleanQuery = queryPlayerId.trim().toUpperCase();

    // Validate format (e.g. PB-XXXXXX or minimum 4 chars)
    if (cleanQuery.length < 4 || cleanQuery.length > 16) {
      return { success: false, error: 'Invalid Player ID format.' };
    }

    const targetProfile = ProfileManager.getInstance().getProfileByPublicId(cleanQuery);
    if (!targetProfile) {
      return {
        success: false,
        error: `No player found with Player ID "${cleanQuery}". Please verify and try again.`,
      };
    }

    // Determine friendship status
    let friendshipStatus: 'NONE' | 'FRIENDS' | 'REQUEST_SENT' | 'REQUEST_RECEIVED' = 'NONE';
    if (this.areFriends(searcherId, targetProfile.id)) {
      friendshipStatus = 'FRIENDS';
    } else if (this.hasPendingRequestFrom(searcherId, targetProfile.id)) {
      friendshipStatus = 'REQUEST_SENT';
    } else if (this.hasPendingRequestFrom(targetProfile.id, searcherId)) {
      friendshipStatus = 'REQUEST_RECEIVED';
    }

    const isOnline = this.isUserOnline(targetProfile.id);
    const winRate = ProfileManager.getInstance().calculateWinRate(targetProfile);

    // Return public information only (no internal IDs, tokens, or private data)
    return {
      success: true,
      player: {
        publicPlayerId: targetProfile.publicPlayerId,
        username: targetProfile.username,
        avatarText: targetProfile.avatarText,
        matchesPlayed: targetProfile.matchesPlayed,
        matchesWon: targetProfile.matchesWon,
        winRate,
        isOnline,
        friendshipStatus,
      },
    };
  }

  // ==================== Friendship Helpers ====================

  public areFriends(userAId: string, userBId: string): boolean {
    if (!userAId || !userBId) return false;
    const friends = this.userFriendsMap.get(userAId);
    return friends ? friends.has(userBId) : false;
  }

  private addFriendship(userAId: string, userBId: string): void {
    if (userAId === userBId) return;

    let friendsA = this.userFriendsMap.get(userAId);
    if (!friendsA) {
      friendsA = new Set();
      this.userFriendsMap.set(userAId, friendsA);
    }
    friendsA.add(userBId);

    let friendsB = this.userFriendsMap.get(userBId);
    if (!friendsB) {
      friendsB = new Set();
      this.userFriendsMap.set(userBId, friendsB);
    }
    friendsB.add(userAId);

    this.friendshipsList.push({
      userAId: userAId < userBId ? userAId : userBId,
      userBId: userAId < userBId ? userBId : userAId,
      createdAt: new Date().toISOString(),
    });
  }

  public removeFriend(
    userId: string,
    targetPublicIdOrId: string
  ): { success: boolean; error?: string } {
    const targetProfile =
      ProfileManager.getInstance().getProfileByPublicId(targetPublicIdOrId) ||
      ProfileManager.getInstance().getProfileById(targetPublicIdOrId);

    if (!targetProfile) {
      return { success: false, error: 'Target player not found.' };
    }

    const targetId = targetProfile.id;
    if (!this.areFriends(userId, targetId)) {
      return { success: false, error: 'You are not friends with this player.' };
    }

    this.userFriendsMap.get(userId)?.delete(targetId);
    this.userFriendsMap.get(targetId)?.delete(userId);

    this.friendshipsList = this.friendshipsList.filter(
      (f) =>
        !(
          (f.userAId === userId && f.userBId === targetId) ||
          (f.userAId === targetId && f.userBId === userId)
        )
    );

    return { success: true };
  }

  public getFriendsList(
    userId: string,
    getRoomCodeFn?: (userId: string) => string | undefined
  ): FriendDTO[] {
    const friendIds = this.userFriendsMap.get(userId);
    if (!friendIds || friendIds.size === 0) return [];

    const result: FriendDTO[] = [];
    for (const friendId of friendIds) {
      const profile = ProfileManager.getInstance().getProfileById(friendId);
      if (!profile) continue;

      const isOnline = this.isUserOnline(friendId);
      const currentRoomCode = getRoomCodeFn ? getRoomCodeFn(friendId) : undefined;
      const winRate = ProfileManager.getInstance().calculateWinRate(profile);

      result.push({
        id: profile.id,
        publicPlayerId: profile.publicPlayerId,
        username: profile.username,
        avatarText: profile.avatarText,
        isOnline,
        currentRoomCode,
        matchesPlayed: profile.matchesPlayed,
        matchesWon: profile.matchesWon,
        winRate,
      });
    }

    // Sort online friends first, then alphabetical by username
    return result.sort((a, b) => {
      if (a.isOnline === b.isOnline) {
        return a.username.localeCompare(b.username);
      }
      return a.isOnline ? -1 : 1;
    });
  }

  // ==================== Friend Requests ====================

  public hasPendingRequestFrom(senderId: string, receiverId: string): boolean {
    const outgoing = this.userOutgoingRequestsMap.get(senderId);
    if (!outgoing) return false;
    for (const reqId of outgoing) {
      const req = this.requestsMap.get(reqId);
      if (req && req.receiverId === receiverId && req.status === 'PENDING') {
        return true;
      }
    }
    return false;
  }

  public sendFriendRequest(
    senderId: string,
    targetPublicId: string
  ): {
    success: boolean;
    error?: string;
    request?: FriendRequestDTO;
    receiverInternalId?: string;
    autoAccepted?: boolean;
  } {
    const senderProfile = ProfileManager.getInstance().getOrCreateProfile(senderId);
    const targetProfile = ProfileManager.getInstance().getProfileByPublicId(targetPublicId);

    if (!targetProfile) {
      return { success: false, error: `Player ID "${targetPublicId}" not found.` };
    }

    if (senderProfile.id === targetProfile.id || senderProfile.publicPlayerId === targetProfile.publicPlayerId) {
      return { success: false, error: 'You cannot send a friend request to yourself.' };
    }

    if (this.areFriends(senderProfile.id, targetProfile.id)) {
      return { success: false, error: 'You are already friends with this player.' };
    }

    if (this.hasPendingRequestFrom(senderProfile.id, targetProfile.id)) {
      return { success: false, error: 'A pending friend request has already been sent to this player.' };
    }

    // Cross-request check: if target has already sent a pending request to sender, auto-accept it!
    const incomingFromTarget = this.findPendingRequest(targetProfile.id, senderProfile.id);
    if (incomingFromTarget) {
      const acceptResult = this.respondToFriendRequest(senderProfile.id, incomingFromTarget.requestId, 'ACCEPT');
      return {
        success: true,
        autoAccepted: true,
        request: acceptResult.request,
        receiverInternalId: targetProfile.id,
      };
    }

    const requestId = randomUUID();
    const now = new Date().toISOString();
    const requestRecord: FriendRequestRecord = {
      requestId,
      senderId: senderProfile.id,
      senderUsername: senderProfile.username,
      senderPublicId: senderProfile.publicPlayerId,
      senderAvatarText: senderProfile.avatarText,
      receiverId: targetProfile.id,
      receiverUsername: targetProfile.username,
      receiverPublicId: targetProfile.publicPlayerId,
      status: 'PENDING',
      createdAt: now,
      updatedAt: now,
    };

    this.requestsMap.set(requestId, requestRecord);

    // Track outgoing
    let outgoing = this.userOutgoingRequestsMap.get(senderProfile.id);
    if (!outgoing) {
      outgoing = new Set();
      this.userOutgoingRequestsMap.set(senderProfile.id, outgoing);
    }
    outgoing.add(requestId);

    // Track incoming
    let incoming = this.userIncomingRequestsMap.get(targetProfile.id);
    if (!incoming) {
      incoming = new Set();
      this.userIncomingRequestsMap.set(targetProfile.id, incoming);
    }
    incoming.add(requestId);

    // Add In-App Notification for target
    this.addNotification(
      targetProfile.id,
      'FRIEND_REQUEST',
      'New Friend Request',
      `${senderProfile.username} (${senderProfile.publicPlayerId}) sent you a friend request.`,
      {
        requestId,
        senderPublicId: senderProfile.publicPlayerId,
        senderUsername: senderProfile.username,
      }
    );

    return {
      success: true,
      request: this.toFriendRequestDTO(requestRecord),
      receiverInternalId: targetProfile.id,
    };
  }

  private findPendingRequest(senderId: string, receiverId: string): FriendRequestRecord | undefined {
    const outgoing = this.userOutgoingRequestsMap.get(senderId);
    if (!outgoing) return undefined;
    for (const reqId of outgoing) {
      const req = this.requestsMap.get(reqId);
      if (req && req.receiverId === receiverId && req.status === 'PENDING') {
        return req;
      }
    }
    return undefined;
  }

  public respondToFriendRequest(
    userId: string,
    requestId: string,
    action: 'ACCEPT' | 'DECLINE'
  ): {
    success: boolean;
    error?: string;
    request?: FriendRequestDTO;
    senderInternalId?: string;
  } {
    const req = this.requestsMap.get(requestId);
    if (!req) {
      return { success: false, error: 'Friend request not found.' };
    }

    if (req.receiverId !== userId) {
      return { success: false, error: 'Unauthorized: You can only respond to requests sent to you.' };
    }

    if (req.status !== 'PENDING') {
      return { success: false, error: `This friend request is already ${req.status.toLowerCase()}.` };
    }

    const now = new Date().toISOString();
    req.updatedAt = now;

    if (action === 'ACCEPT') {
      req.status = 'ACCEPTED';
      this.addFriendship(req.senderId, req.receiverId);

      // Notify original sender
      const receiverProfile = ProfileManager.getInstance().getProfileById(userId);
      this.addNotification(
        req.senderId,
        'FRIEND_ACCEPTED',
        'Friend Request Accepted',
        `${receiverProfile?.username || 'Player'} accepted your friend request!`,
        {
          requestId,
          friendPublicId: req.receiverPublicId,
          friendUsername: req.receiverUsername,
        }
      );
    } else {
      req.status = 'DECLINED';
    }

    // Clean up from pending maps
    this.userOutgoingRequestsMap.get(req.senderId)?.delete(requestId);
    this.userIncomingRequestsMap.get(req.receiverId)?.delete(requestId);

    return {
      success: true,
      request: this.toFriendRequestDTO(req),
      senderInternalId: req.senderId,
    };
  }

  public cancelFriendRequest(
    userId: string,
    requestId: string
  ): { success: boolean; error?: string } {
    const req = this.requestsMap.get(requestId);
    if (!req) {
      return { success: false, error: 'Friend request not found.' };
    }

    if (req.senderId !== userId) {
      return { success: false, error: 'Unauthorized: You can only cancel requests you sent.' };
    }

    if (req.status !== 'PENDING') {
      return { success: false, error: `This friend request is already ${req.status.toLowerCase()}.` };
    }

    req.status = 'CANCELLED';
    req.updatedAt = new Date().toISOString();

    this.userOutgoingRequestsMap.get(req.senderId)?.delete(requestId);
    this.userIncomingRequestsMap.get(req.receiverId)?.delete(requestId);

    return { success: true };
  }

  public getFriendRequests(userId: string): {
    incoming: FriendRequestDTO[];
    outgoing: FriendRequestDTO[];
  } {
    const incoming: FriendRequestDTO[] = [];
    const incomingIds = this.userIncomingRequestsMap.get(userId);
    if (incomingIds) {
      for (const id of incomingIds) {
        const req = this.requestsMap.get(id);
        if (req && req.status === 'PENDING') {
          incoming.push(this.toFriendRequestDTO(req));
        }
      }
    }

    const outgoing: FriendRequestDTO[] = [];
    const outgoingIds = this.userOutgoingRequestsMap.get(userId);
    if (outgoingIds) {
      for (const id of outgoingIds) {
        const req = this.requestsMap.get(id);
        if (req && req.status === 'PENDING') {
          outgoing.push(this.toFriendRequestDTO(req));
        }
      }
    }

    return { incoming, outgoing };
  }

  private toFriendRequestDTO(record: FriendRequestRecord): FriendRequestDTO {
    return {
      requestId: record.requestId,
      senderId: record.senderId,
      senderUsername: record.senderUsername,
      senderPublicId: record.senderPublicId,
      senderAvatarText: record.senderAvatarText,
      receiverId: record.receiverId,
      receiverUsername: record.receiverUsername,
      receiverPublicId: record.receiverPublicId,
      status: record.status,
      createdAt: record.createdAt,
    };
  }

  // ==================== Room Invitations & Deep Links ====================

  public hashInviteToken(rawToken: string): string {
    return createHash('sha256').update(rawToken.trim()).digest('hex');
  }

  public createRoomInviteLink(
    hostId: string,
    roomCode: string,
    roomManager: any,
    maxUses: number = 8,
    expiresInMs: number = 15 * 60 * 1000
  ): {
    success: boolean;
    error?: string;
    token?: string;
    inviteUrl?: string;
    expiresAt?: number;
  } {
    const room = roomManager.getRoom(roomCode);
    if (!room) {
      return { success: false, error: 'Room does not exist.' };
    }

    if (room.hostId !== hostId) {
      return { success: false, error: 'Only the room host can create invitation links.' };
    }

    const hostProfile = ProfileManager.getInstance().getOrCreateProfile(hostId);
    const rawToken = randomBytes(24).toString('base64url');
    const tokenHash = this.hashInviteToken(rawToken);
    const invitationId = randomUUID();
    const now = Date.now();
    const expiresAt = now + expiresInMs;

    const record: RoomInvitationRecord = {
      invitationId,
      roomCode: room.roomCode,
      tokenHash,
      hostId,
      hostUsername: hostProfile.username,
      hostPublicId: hostProfile.publicPlayerId,
      status: 'PENDING',
      type: 'SHAREABLE_LINK',
      maxUses,
      usedCount: 0,
      createdAt: now,
      expiresAt,
    };

    this.invitationsMap.set(invitationId, record);
    this.tokenHashToInvitationMap.set(tokenHash, record);

    let roomInvites = this.roomInvitationsMap.get(room.roomCode);
    if (!roomInvites) {
      roomInvites = new Set();
      this.roomInvitationsMap.set(room.roomCode, roomInvites);
    }
    roomInvites.add(invitationId);

    const baseUrl = process.env.INVITE_BASE_URL || 'https://powerbid.app/invite';
    const inviteUrl = `${baseUrl}/${rawToken}`;

    return {
      success: true,
      token: rawToken,
      inviteUrl,
      expiresAt,
    };
  }

  public revokeRoomInvitations(
    hostId: string,
    roomCode: string,
    roomManager: any
  ): { success: boolean; error?: string } {
    const room = roomManager.getRoom(roomCode);
    if (!room) return { success: false, error: 'Room not found.' };
    if (room.hostId !== hostId) return { success: false, error: 'Only the room host can revoke invitations.' };

    const inviteIds = this.roomInvitationsMap.get(roomCode);
    if (inviteIds) {
      for (const id of inviteIds) {
        const inv = this.invitationsMap.get(id);
        if (inv && inv.status === 'PENDING') {
          inv.status = 'REVOKED';
        }
      }
    }
    return { success: true };
  }

  public previewInvite(
    rawToken: string,
    roomManager: any
  ): {
    success: boolean;
    error?: string;
    preview?: RoomPreviewDTO;
  } {
    if (!rawToken || typeof rawToken !== 'string') {
      return { success: false, error: 'Invitation token is missing or malformed.' };
    }

    const tokenHash = this.hashInviteToken(rawToken);
    const invitation = this.tokenHashToInvitationMap.get(tokenHash);

    if (!invitation) {
      return { success: false, error: 'Invalid or unrecognized invitation link.' };
    }

    if (invitation.status === 'REVOKED') {
      return {
        success: false,
        error: 'This invitation link has been revoked by the host.',
        preview: {
          roomCode: invitation.roomCode,
          hostUsername: invitation.hostUsername,
          category: 'Unknown',
          gameMode: 'AUCTION_TEAM_CHALLENGE',
          itemCount: 0,
          timerDuration: 15,
          currentPlayersCount: 0,
          maxPlayers: 8,
          isOpen: false,
          status: 'REVOKED',
        },
      };
    }

    if (Date.now() > invitation.expiresAt || invitation.status === 'EXPIRED') {
      invitation.status = 'EXPIRED';
      return {
        success: false,
        error: 'This invitation link has expired.',
        preview: {
          roomCode: invitation.roomCode,
          hostUsername: invitation.hostUsername,
          category: 'Unknown',
          gameMode: 'AUCTION_TEAM_CHALLENGE',
          itemCount: 0,
          timerDuration: 15,
          currentPlayersCount: 0,
          maxPlayers: 8,
          isOpen: false,
          status: 'EXPIRED',
        },
      };
    }

    const room = roomManager.getRoom(invitation.roomCode);
    if (!room) {
      return {
        success: false,
        error: 'The auction room no longer exists or has closed.',
        preview: {
          roomCode: invitation.roomCode,
          hostUsername: invitation.hostUsername,
          category: 'Closed',
          gameMode: 'AUCTION_TEAM_CHALLENGE',
          itemCount: 0,
          timerDuration: 15,
          currentPlayersCount: 0,
          maxPlayers: 8,
          isOpen: false,
          status: 'EXPIRED',
        },
      };
    }

    const isMatchStarted = room.auctionEngine && room.auctionEngine.getState().phase !== 'LOBBY';
    const isFull = room.players.length >= room.maxPlayers;
    let previewStatus: 'AVAILABLE' | 'FULL' | 'EXPIRED' | 'REVOKED' | 'IN_PROGRESS' = 'AVAILABLE';

    if (isMatchStarted) {
      previewStatus = 'IN_PROGRESS';
    } else if (isFull) {
      previewStatus = 'FULL';
    }

    // STRICT PRIVACY: NEVER leak hidden item points, formulas, or character lists!
    const preview: RoomPreviewDTO = {
      roomCode: room.roomCode,
      hostUsername: invitation.hostUsername,
      category: room.category,
      gameMode: room.gameMode,
      itemCount: room.itemCount,
      timerDuration: room.timerDuration,
      currentPlayersCount: room.players.length,
      maxPlayers: room.maxPlayers,
      isOpen: previewStatus === 'AVAILABLE',
      status: previewStatus,
    };

    return {
      success: true,
      preview,
    };
  }

  public validateAndConsumeInviteToken(
    rawToken: string,
    roomManager: any
  ): {
    success: boolean;
    error?: string;
    roomCode?: string;
  } {
    const previewRes = this.previewInvite(rawToken, roomManager);
    if (!previewRes.success || !previewRes.preview) {
      return { success: false, error: previewRes.error || 'Invitation is invalid.' };
    }

    if (!previewRes.preview.isOpen) {
      if (previewRes.preview.status === 'FULL') {
        return { success: false, error: 'Auction room is full (Max 8 players).' };
      }
      if (previewRes.preview.status === 'IN_PROGRESS') {
        return { success: false, error: 'Auction match has already started.' };
      }
      return { success: false, error: `Cannot join room: invitation is ${previewRes.preview.status.toLowerCase()}.` };
    }

    const tokenHash = this.hashInviteToken(rawToken);
    const invitation = this.tokenHashToInvitationMap.get(tokenHash);
    if (invitation) {
      invitation.usedCount += 1;
      if (invitation.usedCount >= invitation.maxUses) {
        invitation.status = 'JOINED';
      }
    }

    return { success: true, roomCode: previewRes.preview.roomCode };
  }

  public inviteFriendsToRoom(
    hostId: string,
    roomCode: string,
    friendPublicIds: string[],
    roomManager: any
  ): {
    success: boolean;
    error?: string;
    invitedCount?: number;
    invitedPlayers?: { id: string; publicPlayerId: string; username: string }[];
  } {
    const room = roomManager.getRoom(roomCode);
    if (!room) {
      return { success: false, error: 'Room does not exist.' };
    }

    if (room.hostId !== hostId) {
      return { success: false, error: 'Only the room host can invite players.' };
    }

    const availableSlots = room.maxPlayers - room.players.length;
    if (availableSlots <= 0) {
      return { success: false, error: 'Room is already full.' };
    }

    const hostProfile = ProfileManager.getInstance().getOrCreateProfile(hostId);
    const invitedPlayers: { id: string; publicPlayerId: string; username: string }[] = [];

    for (const publicId of friendPublicIds) {
      const friendProfile = ProfileManager.getInstance().getProfileByPublicId(publicId);
      if (!friendProfile) continue;

      if (!this.areFriends(hostId, friendProfile.id)) {
        continue; // Only confirmed friends can be invited via direct friend invite
      }

      // Check if friend is already in the room
      if (room.players.some((p: any) => p.id === friendProfile.id)) {
        continue;
      }

      // Create direct invitation record
      const invitationId = randomUUID();
      const rawToken = randomBytes(24).toString('base64url');
      const tokenHash = this.hashInviteToken(rawToken);
      const now = Date.now();
      const expiresAt = now + 15 * 60 * 1000;

      const record: RoomInvitationRecord = {
        invitationId,
        roomCode: room.roomCode,
        tokenHash,
        hostId,
        hostUsername: hostProfile.username,
        hostPublicId: hostProfile.publicPlayerId,
        targetPlayerId: friendProfile.id,
        targetPublicId: friendProfile.publicPlayerId,
        status: 'PENDING',
        type: 'DIRECT_FRIEND',
        maxUses: 1,
        usedCount: 0,
        createdAt: now,
        expiresAt,
      };

      this.invitationsMap.set(invitationId, record);
      this.tokenHashToInvitationMap.set(tokenHash, record);

      let roomInvites = this.roomInvitationsMap.get(room.roomCode);
      if (!roomInvites) {
        roomInvites = new Set();
        this.roomInvitationsMap.set(room.roomCode, roomInvites);
      }
      roomInvites.add(invitationId);

      // Create in-app notification
      this.addNotification(
        friendProfile.id,
        'ROOM_INVITE',
        'Auction Room Invitation',
        `${hostProfile.username} invited you to join auction room ${room.roomCode} (${room.category}).`,
        {
          invitationId,
          roomCode: room.roomCode,
          hostUsername: hostProfile.username,
          hostPublicId: hostProfile.publicPlayerId,
          category: room.category,
          token: rawToken,
          expiresAt,
        }
      );

      invitedPlayers.push({
        id: friendProfile.id,
        publicPlayerId: friendProfile.publicPlayerId,
        username: friendProfile.username,
      });
    }

    return {
      success: true,
      invitedCount: invitedPlayers.length,
      invitedPlayers,
    };
  }

  // ==================== In-App Notifications ====================

  public addNotification(
    recipientId: string,
    type: 'FRIEND_REQUEST' | 'FRIEND_ACCEPTED' | 'ROOM_INVITE',
    title: string,
    message: string,
    data: any
  ): InAppNotificationRecord {
    let list = this.notificationsMap.get(recipientId);
    if (!list) {
      list = [];
      this.notificationsMap.set(recipientId, list);
    }

    // Deduplication: prevent identical pending notification
    if (type === 'ROOM_INVITE' && data?.roomCode) {
      const existing = list.find((n) => !n.isRead && n.type === 'ROOM_INVITE' && n.data?.roomCode === data.roomCode);
      if (existing) {
        existing.createdAt = new Date().toISOString();
        return existing;
      }
    } else if (type === 'FRIEND_REQUEST' && data?.requestId) {
      const existing = list.find((n) => !n.isRead && n.type === 'FRIEND_REQUEST' && n.data?.requestId === data.requestId);
      if (existing) {
        existing.createdAt = new Date().toISOString();
        return existing;
      }
    }

    const record: InAppNotificationRecord = {
      id: randomUUID(),
      recipientId,
      type,
      title,
      message,
      data,
      isRead: false,
      createdAt: new Date().toISOString(),
    };

    list.unshift(record);
    // Keep max 50 notifications per user
    if (list.length > 50) {
      list.pop();
    }

    return record;
  }

  public getNotifications(recipientId: string): InAppNotificationDTO[] {
    const list = this.notificationsMap.get(recipientId);
    if (!list) return [];
    return list.map((n) => ({
      id: n.id,
      recipientId: n.recipientId,
      type: n.type,
      title: n.title,
      message: n.message,
      data: n.data,
      isRead: n.isRead,
      createdAt: n.createdAt,
    }));
  }

  public markNotificationRead(recipientId: string, notificationId: string): boolean {
    const list = this.notificationsMap.get(recipientId);
    if (!list) return false;
    const notification = list.find((n) => n.id === notificationId);
    if (notification) {
      notification.isRead = true;
      return true;
    }
    return false;
  }

  public clearNotifications(recipientId: string): void {
    this.notificationsMap.set(recipientId, []);
  }

  /**
   * Cleans up expired invitations (invocable periodically)
   */
  public cleanupExpiredInvitations(): number {
    const now = Date.now();
    let cleaned = 0;
    for (const [id, inv] of this.invitationsMap) {
      if (inv.status === 'PENDING' && now > inv.expiresAt) {
        inv.status = 'EXPIRED';
        cleaned++;
      }
    }
    return cleaned;
  }
}
