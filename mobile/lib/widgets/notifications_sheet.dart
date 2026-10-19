import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../models/friend_model.dart';
import '../screens/friends_screen.dart';
import 'room_preview_dialog.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ValueListenableBuilder<List<InAppNotificationModel>>(
          valueListenable: SocketService.instance.notificationsNotifier,
          builder: (context, notifications, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_rounded, color: AppTheme.accent, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          for (final n in notifications) {
                            if (!n.isRead) {
                              SocketService.instance.markNotificationRead(n.id);
                            }
                          }
                        },
                        child: const Text('Mark all as read', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Notifications',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, unused) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, idx) {
                        final notif = notifications[idx];
                        return _buildNotificationItem(context, notif);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, InAppNotificationModel notif) {
    IconData icon;
    Color iconColor;

    switch (notif.type) {
      case 'ROOM_INVITE':
        icon = Icons.mail_rounded;
        iconColor = AppTheme.primary;
        break;
      case 'FRIEND_REQUEST':
        icon = Icons.person_add_rounded;
        iconColor = AppTheme.accent;
        break;
      case 'FRIEND_ACCEPTED':
        icon = Icons.how_to_reg_rounded;
        iconColor = AppTheme.success;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppTheme.textSecondary;
    }

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          SocketService.instance.markNotificationRead(notif.id);
        }
        if (notif.type == 'ROOM_INVITE' && notif.data['token'] != null) {
          Navigator.pop(context);
          RoomPreviewDialog.show(context, inviteToken: notif.data['token'].toString());
        } else if (notif.type == 'FRIEND_REQUEST') {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 1)),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  if (notif.type == 'ROOM_INVITE' && notif.data['token'] != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        RoomPreviewDialog.show(context, inviteToken: notif.data['token'].toString());
                      },
                      child: const Text('View Room Preview', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
