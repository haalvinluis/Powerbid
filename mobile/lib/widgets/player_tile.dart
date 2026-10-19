import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/player_model.dart';

class PlayerTile extends StatelessWidget {
  final PlayerModel? player;
  final int slotIndex;
  final String? name;
  final bool? isHost;
  final bool? isMe;

  const PlayerTile({
    super.key,
    this.player,
    this.slotIndex = 0,
    this.name,
    this.isHost,
    this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveName = name ?? player?.name;
    final effectiveHost = isHost ?? player?.isHost ?? false;
    final effectiveMe = isMe ?? false;
    final isEmpty = effectiveName == null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEmpty ? AppTheme.surface.withValues(alpha: 0.5) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty
              ? AppTheme.surfaceLight.withValues(alpha: 0.5)
              : (effectiveHost ? AppTheme.primary : AppTheme.surfaceLight),
          width: effectiveHost ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isEmpty ? AppTheme.surfaceLight : AppTheme.primary.withValues(alpha: 0.2),
            child: Icon(
              isEmpty ? Icons.person_outline : Icons.person,
              color: isEmpty ? AppTheme.textSecondary : AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEmpty ? 'Slot #${slotIndex + 1} (Waiting for player...)' : '$effectiveName${effectiveMe ? ' (You)' : ''}',
              style: TextStyle(
                color: isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (!isEmpty) ...[
            if (effectiveHost)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary, width: 1),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (player?.isReady == true)
              const Icon(
                Icons.check_circle,
                color: AppTheme.success,
                size: 20,
              ),
          ],
        ],
      ),
    );
  }
}
