import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _showRestoreConfirmation() {
    AudioService().playSfx(SfxType.buttonClick);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Restore Defaults', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to reset all audio, gameplay, and display settings to default values?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.of(context).pop();
              _settings.restoreDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All settings restored to defaults.'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Audio Settings
          _buildSectionHeader('AUDIO SETTINGS', Icons.volume_up),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Master Sound', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Toggle all game audio output', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.masterSound,
                    activeColor: AppTheme.accent,
                    onChanged: (val) {
                      AudioService().playSfx(SfxType.buttonClick);
                      _settings.setMasterSound(val);
                    },
                  ),
                  const Divider(color: AppTheme.surfaceLight),
                  SwitchListTile(
                    title: const Text('Sound Effects (SFX)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Bids, timer ticks, item announcements', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.sfxEnabled,
                    activeColor: AppTheme.accent,
                    onChanged: _settings.masterSound
                        ? (val) {
                            AudioService().playSfx(SfxType.buttonClick);
                            _settings.setSfxEnabled(val);
                          }
                        : null,
                  ),
                  const Divider(color: AppTheme.surfaceLight),
                  SwitchListTile(
                    title: const Text('Background Music', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Lobby & match background music', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.musicEnabled,
                    activeColor: AppTheme.accent,
                    onChanged: _settings.masterSound
                        ? (val) {
                            AudioService().playSfx(SfxType.buttonClick);
                            _settings.setMusicEnabled(val);
                          }
                        : null,
                  ),
                  const Divider(color: AppTheme.surfaceLight),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Master Volume', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${(_settings.masterVolume * 100).toInt()}%',
                              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Slider(
                          value: _settings.masterVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          activeColor: AppTheme.accent,
                          inactiveColor: AppTheme.surfaceLight,
                          onChanged: _settings.masterSound
                              ? (val) => _settings.setMasterVolume(val)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Gameplay Settings
          _buildSectionHeader('GAMEPLAY PREFERENCES', Icons.gamepad),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Vibration Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Haptic responses on bids & countdown warnings', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.vibrationEnabled,
                    activeColor: AppTheme.accent,
                    onChanged: (val) {
                      AudioService().playSfx(SfxType.buttonClick);
                      _settings.setVibrationEnabled(val);
                    },
                  ),
                  const Divider(color: AppTheme.surfaceLight),
                  SwitchListTile(
                    title: const Text('Confirm High Bids', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Prompt for confirmation when bidding > 50% remaining budget', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.confirmBidDialog,
                    activeColor: AppTheme.accent,
                    onChanged: (val) {
                      AudioService().playSfx(SfxType.buttonClick);
                      _settings.setConfirmBidDialog(val);
                    },
                  ),
                  const Divider(color: AppTheme.surfaceLight),
                  SwitchListTile(
                    title: const Text('Confirm Leave Match', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Warn before forfeiting active auction match', style: TextStyle(color: AppTheme.textSecondary)),
                    value: _settings.confirmLeaveMatch,
                    activeColor: AppTheme.accent,
                    onChanged: (val) {
                      AudioService().playSfx(SfxType.buttonClick);
                      _settings.setConfirmLeaveMatch(val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Display & Accessibility
          _buildSectionHeader('DISPLAY & ACCESSIBILITY', Icons.display_settings),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest)),
                    ],
                    selected: {_settings.themeMode},
                    onSelectionChanged: (Set<ThemeMode> selection) {
                      AudioService().playSfx(SfxType.buttonClick);
                      _settings.setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppTheme.surfaceLight),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Text Scaling Factor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${(_settings.textScale * 100).toInt()}%',
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: [0.85, 1.0, 1.15, 1.30].map((scale) {
                      final isSelected = _settings.textScale == scale;
                      final label = scale == 0.85
                          ? 'Small'
                          : scale == 1.0
                              ? 'Normal'
                              : scale == 1.15
                                  ? 'Large'
                                  : 'X-Large';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        onSelected: (selected) {
                          if (selected) {
                            AudioService().playSfx(SfxType.buttonClick);
                            _settings.setTextScale(scale);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Restore Defaults
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
            icon: const Icon(Icons.restore),
            label: const Text('RESTORE DEFAULT SETTINGS'),
            onPressed: _showRestoreConfirmation,
          ),
          const SizedBox(height: 24),

          // Section 5: About PowerBid
          _buildSectionHeader('ABOUT', Icons.info_outline),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppTheme.electricBlue, size: 28),
                      const SizedBox(width: 8),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Power',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.gold,
                              ),
                            ),
                            TextSpan(
                              text: 'Bid',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Chip(
                        label: Text('v1.0.0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: AppTheme.surfaceLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Real-Time Multiplayer Auction Game. Draft high-scoring characters, manage budgets, and outbid opponents in live arenas.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
