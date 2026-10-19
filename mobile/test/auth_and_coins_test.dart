import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2: Persistent Guest Profiles & Device UUID Tests', () {
    test('Should generate and persist a unique guest UUID on initial app launch', () async {
      final auth = AuthService.instance;
      await auth.init();

      expect(auth.guestPlayerId.isNotEmpty, isTrue);
      expect(auth.guestPlayerId.startsWith('pb_guest_'), isTrue);
      expect(auth.isGuestNotifier.value, isTrue);
      expect(auth.isLoggedInNotifier.value, isFalse);
      expect(auth.coinBalanceNotifier.value, equals(500));
    });

    test('Should restore the exact same guest UUID after app restart', () async {
      // First session: initial launch
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': 'pb_guest_device_permanent_12345',
      });

      final auth = AuthService.instance;
      await auth.init();

      expect(auth.guestPlayerId, equals('pb_guest_device_permanent_12345'));
      expect(auth.isGuestNotifier.value, isTrue);
    });
  });

  group('Phase 2: Registered Account Sessions & Token Storage Tests', () {
    test('Should restore registered session token and email from storage', () async {
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': 'pb_guest_abc',
        'powerbid_auth_token': 'pbt_test_session_token_xyz',
        'powerbid_user_email': 'proplayer@powerbid.com',
        'powerbid_account_id': 'acc_98765',
      });

      final auth = AuthService.instance;
      await auth.init();

      expect(auth.isLoggedInNotifier.value, isTrue);
      expect(auth.isGuestNotifier.value, isFalse);
      expect(auth.sessionToken, equals('pbt_test_session_token_xyz'));
      expect(auth.userEmail, equals('proplayer@powerbid.com'));
      expect(auth.accountId, equals('acc_98765'));
    });

    test('Should clear session token and revert to guest mode on logout', () async {
      SharedPreferences.setMockInitialValues({
        'powerbid_guest_player_id': 'pb_guest_abc',
        'powerbid_auth_token': 'pbt_test_session_token_xyz',
        'powerbid_user_email': 'proplayer@powerbid.com',
      });

      final auth = AuthService.instance;
      await auth.init();
      expect(auth.isLoggedInNotifier.value, isTrue);

      await auth.logout();

      expect(auth.isLoggedInNotifier.value, isFalse);
      expect(auth.isGuestNotifier.value, isTrue);
      expect(auth.sessionToken, isNull);
      expect(auth.userEmail, isNull);
      // Persistent guest ID must still be preserved
      expect(auth.guestPlayerId, equals('pb_guest_abc'));
    });
  });

  group('Phase 2: Virtual Coin Wallet & Reactivity Tests', () {
    test('Should update reactive coin balance when match reward is credited', () {
      final auth = AuthService.instance;
      expect(auth.coinBalanceNotifier.value, equals(500));

      // Credited 150 coins for win
      auth.updateCoinBalance(650);
      expect(auth.coinBalanceNotifier.value, equals(650));

      // Credited 25 coins for participation
      auth.updateCoinBalance(675);
      expect(auth.coinBalanceNotifier.value, equals(675));
    });

    test('Should never accept negative coin balance', () {
      final auth = AuthService.instance;
      auth.updateCoinBalance(500);

      // Attempt invalid negative balance
      auth.updateCoinBalance(-10);
      expect(auth.coinBalanceNotifier.value, equals(500));
    });
  });
}
