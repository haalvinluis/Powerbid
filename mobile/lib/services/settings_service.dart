import 'package:flutter/material.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Audio Settings
  bool _masterSound = true;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  double _masterVolume = 1.0;

  // Gameplay Settings
  bool _vibrationEnabled = true;
  bool _confirmBidDialog = false;
  bool _confirmLeaveMatch = true;

  // Display & Accessibility Settings
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScale = 1.0; // 0.85, 1.0, 1.15, 1.30

  // Getters
  bool get masterSound => _masterSound;
  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  double get masterVolume => _masterVolume;

  bool get vibrationEnabled => _vibrationEnabled;
  bool get confirmBidDialog => _confirmBidDialog;
  bool get confirmLeaveMatch => _confirmLeaveMatch;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;

  // Setters
  void setMasterSound(bool val) {
    _masterSound = val;
    notifyListeners();
  }

  void setSfxEnabled(bool val) {
    _sfxEnabled = val;
    notifyListeners();
  }

  void setMusicEnabled(bool val) {
    _musicEnabled = val;
    notifyListeners();
  }

  void setMasterVolume(double val) {
    _masterVolume = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setVibrationEnabled(bool val) {
    _vibrationEnabled = val;
    notifyListeners();
  }

  void setConfirmBidDialog(bool val) {
    _confirmBidDialog = val;
    notifyListeners();
  }

  void setConfirmLeaveMatch(bool val) {
    _confirmLeaveMatch = val;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setTextScale(double scale) {
    _textScale = scale;
    notifyListeners();
  }

  void restoreDefaults() {
    _masterSound = true;
    _sfxEnabled = true;
    _musicEnabled = true;
    _masterVolume = 1.0;

    _vibrationEnabled = true;
    _confirmBidDialog = false;
    _confirmLeaveMatch = true;

    _themeMode = ThemeMode.dark;
    _textScale = 1.0;

    notifyListeners();
  }
}
