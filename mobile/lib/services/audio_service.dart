import 'package:flutter/foundation.dart';
import 'settings_service.dart';

enum SfxType {
  buttonClick,
  playerJoin,
  auctionStart,
  itemAnnounced,
  bidAccepted,
  highestBidder,
  outbid,
  timerWarning,
  itemSold,
  itemUnsold,
  matchVictory,
  matchTie,
  error,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final Map<SfxType, DateTime> _lastPlayedMap = {};
  static const int _dedupWindowMs = 300;

  /// Play SFX with audio preference checks and deduplication filter.
  void playSfx(SfxType type) {
    final settings = SettingsService();

    // Check audio preferences
    if (!settings.masterSound || !settings.sfxEnabled || settings.masterVolume <= 0) {
      return;
    }

    // Deduplication check
    final now = DateTime.now();
    final lastPlayed = _lastPlayedMap[type];
    if (lastPlayed != null && now.difference(lastPlayed).inMilliseconds < _dedupWindowMs) {
      return; // Skip duplicate trigger within debounce window
    }

    _lastPlayedMap[type] = now;

    // Log sound event execution (in full app, triggers system sound or audio asset player)
    if (kDebugMode) {
      print('[AudioService] Play SFX: ${type.name} (Vol: ${(settings.masterVolume * 100).toInt()}%)');
    }
  }

  /// Trigger haptic/vibration feedback if enabled in settings
  void triggerHaptic() {
    final settings = SettingsService();
    if (settings.vibrationEnabled && kDebugMode) {
      print('[AudioService] Haptic feedback triggered');
    }
  }
}
