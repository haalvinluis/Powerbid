import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/powerbid_logo.dart';
import '../widgets/notifications_sheet.dart';
import '../services/audio_service.dart';
import '../services/socket_service.dart';
import 'mode_selection_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'match_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Title Banner with Notification Bell
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.surfaceLight, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(child: PowerBidLogo(iconSize: 42, fontSize: 26)),
                    ValueListenableBuilder<int>(
                      valueListenable: SocketService.instance.unreadNotificationsCountNotifier,
                      builder: (context, unreadCount, _) {
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_rounded, color: AppTheme.accent, size: 28),
                              onPressed: () => NotificationsSheet.show(context),
                              tooltip: 'Notifications',
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Navigation Action Buttons
              Column(
                children: [
                  CustomButton(
                    label: 'Play Online',
                    icon: Icons.play_arrow_rounded,
                    type: ButtonType.primary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Friends & Players',
                    icon: Icons.people_alt_rounded,
                    type: ButtonType.secondary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Profile & Achievements',
                    icon: Icons.person_rounded,
                    type: ButtonType.secondary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Match History',
                    icon: Icons.history_rounded,
                    type: ButtonType.secondary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    type: ButtonType.secondary,
                    onPressed: () {
                      AudioService().playSfx(SfxType.buttonClick);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Footer Badge
              const Text(
                'v0.1.0 • Max 8 Players per Room',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
