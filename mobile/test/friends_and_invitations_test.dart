import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/friend_model.dart';
import 'package:mobile/services/socket_service.dart';

void main() {
  group('Friends & Invitations Models Tests', () {
    test('FriendModel parses from JSON with defaults', () {
      final json = {
        'id': 'socket_123',
        'publicPlayerId': 'PB-A7K9X2',
        'username': 'AuctionKing',
        'avatarText': 'AK',
        'isOnline': true,
        'currentRoomCode': '9X4B2A',
        'matchesPlayed': 12,
        'matchesWon': 8,
        'winRate': 66.7,
      };

      final friend = FriendModel.fromJson(json);

      expect(friend.id, equals('socket_123'));
      expect(friend.publicPlayerId, equals('PB-A7K9X2'));
      expect(friend.username, equals('AuctionKing'));
      expect(friend.avatarText, equals('AK'));
      expect(friend.isOnline, isTrue);
      expect(friend.currentRoomCode, equals('9X4B2A'));
      expect(friend.matchesPlayed, equals(12));
      expect(friend.matchesWon, equals(8));
      expect(friend.winRate, equals(66.7));
    });

    test('FriendModel handles missing or null fields gracefully', () {
      final json = <String, dynamic>{};
      final friend = FriendModel.fromJson(json);

      expect(friend.publicPlayerId, equals('PB-UNKNOWN'));
      expect(friend.username, equals('Player'));
      expect(friend.isOnline, isFalse);
      expect(friend.currentRoomCode, isNull);
      expect(friend.matchesPlayed, equals(0));
      expect(friend.winRate, equals(0.0));
    });

    test('FriendRequestModel parses correctly', () {
      final json = {
        'requestId': 'req-987',
        'senderId': 'user_1',
        'senderUsername': 'Challenger',
        'senderPublicId': 'PB-C4L8N2',
        'senderAvatarText': 'CH',
        'receiverId': 'user_2',
        'receiverUsername': 'Target',
        'receiverPublicId': 'PB-T3G9X1',
        'status': 'PENDING',
        'createdAt': '2026-10-18T10:00:00Z',
      };

      final req = FriendRequestModel.fromJson(json);

      expect(req.requestId, equals('req-987'));
      expect(req.senderUsername, equals('Challenger'));
      expect(req.senderPublicId, equals('PB-C4L8N2'));
      expect(req.receiverPublicId, equals('PB-T3G9X1'));
      expect(req.status, equals('PENDING'));
    });

    test('RoomPreviewModel validates room availability and properties without score leaks', () {
      final json = {
        'roomCode': 'AUCTION9',
        'hostUsername': 'MasterHost',
        'category': 'Cricket',
        'gameMode': 'AUCTION_TEAM_CHALLENGE',
        'itemCount': 10,
        'timerDuration': 20,
        'currentPlayersCount': 3,
        'maxPlayers': 8,
        'isOpen': true,
        'status': 'AVAILABLE',
      };

      final preview = RoomPreviewModel.fromJson(json);

      expect(preview.roomCode, equals('AUCTION9'));
      expect(preview.hostUsername, equals('MasterHost'));
      expect(preview.category, equals('Cricket'));
      expect(preview.itemCount, equals(10));
      expect(preview.timerDuration, equals(20));
      expect(preview.currentPlayersCount, equals(3));
      expect(preview.maxPlayers, equals(8));
      expect(preview.isOpen, isTrue);
      expect(preview.status, equals('AVAILABLE'));
    });

    test('InAppNotificationModel parses room invite and friend request notifications', () {
      final inviteJson = {
        'id': 'notif-111',
        'recipientId': 'user_me',
        'type': 'ROOM_INVITE',
        'title': 'Auction Room Invitation',
        'message': 'Host invited you to join room 7X9K2A',
        'data': {'roomCode': '7X9K2A', 'token': 'sec_tok_xyz123'},
        'isRead': false,
        'createdAt': '2026-10-18T12:00:00Z',
      };

      final notif = InAppNotificationModel.fromJson(inviteJson);

      expect(notif.id, equals('notif-111'));
      expect(notif.type, equals('ROOM_INVITE'));
      expect(notif.data['roomCode'], equals('7X9K2A'));
      expect(notif.data['token'], equals('sec_tok_xyz123'));
      expect(notif.isRead, isFalse);
    });

    test('SocketService maintains notifications notifiers', () {
      final service = SocketService.instance;
      expect(service.notificationsNotifier, isNotNull);
      expect(service.unreadNotificationsCountNotifier, isNotNull);
      expect(service.unreadNotificationsCountNotifier.value, isNonNegative);
    });
  });
}
