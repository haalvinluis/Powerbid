import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'socket_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  static const String _keyGuestId = 'powerbid_guest_player_id';
  static const String _keyAuthToken = 'powerbid_auth_token';
  static const String _keyUserEmail = 'powerbid_user_email';
  static const String _keyAccountId = 'powerbid_account_id';

  String _guestPlayerId = '';
  String? _sessionToken;
  String? _userEmail;
  String? _accountId;

  final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isGuestNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String?> currentUserEmailNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int> coinBalanceNotifier = ValueNotifier<int>(500);

  String get guestPlayerId => _guestPlayerId;
  String? get sessionToken => _sessionToken;
  String? get userEmail => _userEmail;
  String? get accountId => _accountId;

  /// Initializes persistent guest UUID and existing session token from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load or generate persistent guest UUID
      String? savedGuestId = prefs.getString(_keyGuestId);
      if (savedGuestId == null || savedGuestId.trim().isEmpty) {
        savedGuestId = _generatePersistentGuestId();
        await prefs.setString(_keyGuestId, savedGuestId);
        debugPrint('[AuthService] Generated and persisted new guest ID: $savedGuestId');
      } else {
        debugPrint('[AuthService] Restored persisted guest ID: $savedGuestId');
      }
      _guestPlayerId = savedGuestId;

      // 2. Load stored session token and user info
      final savedToken = prefs.getString(_keyAuthToken);
      final savedEmail = prefs.getString(_keyUserEmail);
      final savedAccountId = prefs.getString(_keyAccountId);

      if (savedToken != null && savedToken.trim().isNotEmpty) {
        _sessionToken = savedToken.trim();
        _userEmail = savedEmail;
        _accountId = savedAccountId;
        isLoggedInNotifier.value = true;
        isGuestNotifier.value = false;
        currentUserEmailNotifier.value = savedEmail;
        debugPrint('[AuthService] Restored registered session for: $savedEmail');
      } else {
        _sessionToken = null;
        _userEmail = null;
        _accountId = null;
        isLoggedInNotifier.value = false;
        isGuestNotifier.value = true;
        currentUserEmailNotifier.value = null;
      }
    } catch (e) {
      debugPrint('[AuthService] Error initializing auth storage: $e');
      if (_guestPlayerId.isEmpty) {
        _guestPlayerId = _generatePersistentGuestId();
      }
    }
  }

  /// Generates a secure random persistent device guest UUID.
  String _generatePersistentGuestId() {
    final rng = Random.secure();
    final chars = 'abcdef0123456789';
    final buffer = StringBuffer('pb_guest_');
    for (int i = 0; i < 16; i++) {
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  /// Registers a new email/password account.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final res = await SocketService.instance.registerAccount(
      email: email,
      password: password,
      username: username,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(token: token, email: email, accountId: account['id'] as String?);
      }
      if (res['profile'] != null && res['profile']['coinBalance'] != null) {
        coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
      }
    }

    return res;
  }

  /// Logs into an existing account with email and password.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await SocketService.instance.loginAccount(
      email: email,
      password: password,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(token: token, email: email, accountId: account['id'] as String?);
      }
      if (res['profile'] != null && res['profile']['coinBalance'] != null) {
        coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
      }
    }

    return res;
  }

  /// Links the current guest profile to an email and password account.
  Future<Map<String, dynamic>> linkGuest({
    required String email,
    required String password,
  }) async {
    final res = await SocketService.instance.linkGuestAccount(
      guestPlayerId: _guestPlayerId,
      email: email,
      password: password,
    );

    if (res['success'] == true) {
      final token = res['token'] as String?;
      final account = res['account'] as Map<String, dynamic>?;
      if (token != null && account != null) {
        await _saveSession(token: token, email: email, accountId: account['id'] as String?);
      }
      if (res['profile'] != null && res['profile']['coinBalance'] != null) {
        coinBalanceNotifier.value = res['profile']['coinBalance'] as int;
      }
    }

    return res;
  }

  /// Logs out of the registered account and reverts to guest mode.
  Future<void> logout() async {
    if (_sessionToken != null) {
      await SocketService.instance.logoutAccount(_sessionToken!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyAccountId);
    } catch (e) {
      debugPrint('[AuthService] Error clearing session from storage: $e');
    }

    _sessionToken = null;
    _userEmail = null;
    _accountId = null;
    isLoggedInNotifier.value = false;
    isGuestNotifier.value = true;
    currentUserEmailNotifier.value = null;

    // Refresh socket connection in guest mode
    SocketService.instance.reconnectWithAuth();
  }

  /// Saves session credentials to SharedPreferences.
  Future<void> _saveSession({
    required String token,
    required String email,
    String? accountId,
  }) async {
    _sessionToken = token;
    _userEmail = email;
    _accountId = accountId;
    isLoggedInNotifier.value = true;
    isGuestNotifier.value = false;
    currentUserEmailNotifier.value = email;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
      await prefs.setString(_keyUserEmail, email);
      if (accountId != null) {
        await prefs.setString(_keyAccountId, accountId);
      }
    } catch (e) {
      debugPrint('[AuthService] Error saving session to storage: $e');
    }
  }

  /// Updates coin balance from external sources (e.g., match rewards, profile fetch).
  void updateCoinBalance(int newBalance) {
    if (newBalance >= 0) {
      coinBalanceNotifier.value = newBalance;
    }
  }
}
