import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/player_model.dart';

void main() {
  group('PlayerModel Tests', () {
    test('Constructs player with defaults', () {
      const player = PlayerModel(
        id: 'p123',
        name: 'AlphaTester',
      );

      expect(player.id, 'p123');
      expect(player.name, 'AlphaTester');
      expect(player.isHost, false);
      expect(player.isReady, false);
      expect(player.budget, 1000);
      expect(player.acquiredItems, isEmpty);
      expect(player.isConnected, true);
      expect(player.sessionToken, isNull);
    });

    test('Serializes to JSON and deserializes correctly', () {
      const player = PlayerModel(
        id: 'p456',
        sessionToken: 'sess_token_abc',
        name: 'BetaTester',
        isHost: true,
        isReady: true,
        budget: 750,
        acquiredItems: ['item_1', 'item_2'],
        isConnected: true,
      );

      final json = player.toJson();
      expect(json['id'], 'p456');
      expect(json['sessionToken'], 'sess_token_abc');
      expect(json['name'], 'BetaTester');
      expect(json['isHost'], true);
      expect(json['budget'], 750);
      expect(json['acquiredItems'], ['item_1', 'item_2']);

      final restored = PlayerModel.fromJson(json);
      expect(restored.id, player.id);
      expect(restored.sessionToken, player.sessionToken);
      expect(restored.name, player.name);
      expect(restored.isHost, player.isHost);
      expect(restored.budget, player.budget);
      expect(restored.acquiredItems.length, 2);
      expect(restored.isConnected, true);
    });

    test('Handles null fields with robust fallbacks', () {
      final json = <String, dynamic>{
        'id': 'p789',
      };

      final fallbackPlayer = PlayerModel.fromJson(json);
      expect(fallbackPlayer.id, 'p789');
      expect(fallbackPlayer.name, 'Player');
      expect(fallbackPlayer.isHost, false);
      expect(fallbackPlayer.budget, 1000);
      expect(fallbackPlayer.acquiredItems, isEmpty);
      expect(fallbackPlayer.isConnected, true);
    });
  });
}
