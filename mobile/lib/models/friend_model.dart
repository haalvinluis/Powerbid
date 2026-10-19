class FriendModel {
  final String id;
  final String publicPlayerId;
  final String username;
  final String avatarText;
  final bool isOnline;
  final String? currentRoomCode;
  final int matchesPlayed;
  final int matchesWon;
  final double winRate;

  const FriendModel({
    required this.id,
    required this.publicPlayerId,
    required this.username,
    required this.avatarText,
    required this.isOnline,
    this.currentRoomCode,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.winRate,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id']?.toString() ?? '',
      publicPlayerId: json['publicPlayerId']?.toString() ?? json['playerId']?.toString() ?? 'PB-UNKNOWN',
      username: json['username']?.toString() ?? 'Player',
      avatarText: json['avatarText']?.toString() ?? '⚡',
      isOnline: json['isOnline'] == true,
      currentRoomCode: json['currentRoomCode']?.toString(),
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FriendRequestModel {
  final String requestId;
  final String senderId;
  final String senderUsername;
  final String senderPublicId;
  final String senderAvatarText;
  final String receiverId;
  final String receiverUsername;
  final String receiverPublicId;
  final String status;
  final String createdAt;

  const FriendRequestModel({
    required this.requestId,
    required this.senderId,
    required this.senderUsername,
    required this.senderPublicId,
    required this.senderAvatarText,
    required this.receiverId,
    required this.receiverUsername,
    required this.receiverPublicId,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      requestId: json['requestId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderUsername: json['senderUsername']?.toString() ?? 'Player',
      senderPublicId: json['senderPublicId']?.toString() ?? '',
      senderAvatarText: json['senderAvatarText']?.toString() ?? '⚡',
      receiverId: json['receiverId']?.toString() ?? '',
      receiverUsername: json['receiverUsername']?.toString() ?? 'Player',
      receiverPublicId: json['receiverPublicId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class RoomPreviewModel {
  final String roomCode;
  final String hostUsername;
  final String category;
  final String gameMode;
  final int itemCount;
  final int timerDuration;
  final int currentPlayersCount;
  final int maxPlayers;
  final bool isOpen;
  final String status; // 'AVAILABLE' | 'FULL' | 'EXPIRED' | 'REVOKED' | 'IN_PROGRESS'

  const RoomPreviewModel({
    required this.roomCode,
    required this.hostUsername,
    required this.category,
    required this.gameMode,
    required this.itemCount,
    required this.timerDuration,
    required this.currentPlayersCount,
    required this.maxPlayers,
    required this.isOpen,
    required this.status,
  });

  factory RoomPreviewModel.fromJson(Map<String, dynamic> json) {
    return RoomPreviewModel(
      roomCode: json['roomCode']?.toString() ?? '',
      hostUsername: json['hostUsername']?.toString() ?? 'Host',
      category: json['category']?.toString() ?? 'Auction',
      gameMode: json['gameMode']?.toString() ?? 'AUCTION_TEAM_CHALLENGE',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 5,
      timerDuration: (json['timerDuration'] as num?)?.toInt() ?? 15,
      currentPlayersCount: (json['currentPlayersCount'] as num?)?.toInt() ?? 1,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 8,
      isOpen: json['isOpen'] == true,
      status: json['status']?.toString() ?? 'AVAILABLE',
    );
  }
}

class InAppNotificationModel {
  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final String createdAt;

  const InAppNotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory InAppNotificationModel.fromJson(Map<String, dynamic> json) {
    return InAppNotificationModel(
      id: json['id']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'NOTIFICATION',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      data: json['data'] != null && json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      isRead: json['isRead'] == true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
