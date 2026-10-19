import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/settings_service.dart';
import 'package:mobile/services/audio_service.dart';

void main() {
  group('SettingsService & AudioService Tests', () {
    test('SettingsService maintains singleton state and notify listeners', () {
      final s1 = SettingsService();
      final s2 = SettingsService();
      expect(identical(s1, s2), true);

      var notified = false;
      void listener() {
        notified = true;
      }

      s1.addListener(listener);

      s1.setMasterSound(false);
      expect(s1.masterSound, false);
      expect(notified, true);

      notified = false;
      s1.setMasterVolume(0.75);
      expect(s1.masterVolume, 0.75);
      expect(notified, true);

      // Clamp test
      s1.setMasterVolume(1.5);
      expect(s1.masterVolume, 1.0);

      s1.removeListener(listener);

      // Restore
      s1.setMasterSound(true);
      s1.setMasterVolume(1.0);
    });

    test('AudioService does not crash on SFX and haptic playback', () {
      final audio = AudioService();
      expect(() => audio.playSfx(SfxType.buttonClick), returnsNormally);
      expect(() => audio.playSfx(SfxType.bidAccepted), returnsNormally);
      expect(() => audio.playSfx(SfxType.matchVictory), returnsNormally);
      expect(() => audio.triggerHaptic(), returnsNormally);
    });
  });
}
