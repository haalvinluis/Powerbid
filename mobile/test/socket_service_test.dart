import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/socket_service.dart';

void main() {
  group('SocketService Initialization & Configuration Tests', () {
    test('Singleton instance is consistent', () {
      final s1 = SocketService.instance;
      final s2 = SocketService.instance;
      expect(identical(s1, s2), true);
    });

    test('Initial notifiers have expected defaults', () {
      final service = SocketService.instance;
      expect(service.isConnectedNotifier.value, false);
      expect(service.currentRoomNotifier.value, isNull);
      expect(service.auctionNotifier.value, isNull);
      expect(service.errorNotifier.value, isNull);
    });

    test('Server URL can be updated and trimmed', () {
      final service = SocketService.instance;
      const testUrl = '   http://192.168.1.50:3000   ';
      service.updateServerUrl(testUrl);
      expect(service.serverUrl, 'http://192.168.1.50:3000');
    });

    test('Rejects blank server URL update', () {
      final service = SocketService.instance;
      final current = service.serverUrl;
      service.updateServerUrl('   ');
      expect(service.serverUrl, current);
    });
  });
}
