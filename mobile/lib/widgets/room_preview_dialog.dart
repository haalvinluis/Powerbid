import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../models/friend_model.dart';
import '../screens/lobby_screen.dart';

class RoomPreviewDialog extends StatefulWidget {
  final String inviteToken;
  final String defaultUsername;

  const RoomPreviewDialog({
    super.key,
    required this.inviteToken,
    this.defaultUsername = 'Player',
  });

  static Future<void> show(
    BuildContext context, {
    required String inviteToken,
    String defaultUsername = 'Player',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RoomPreviewDialog(
        inviteToken: inviteToken,
        defaultUsername: defaultUsername,
      ),
    );
  }

  @override
  State<RoomPreviewDialog> createState() => _RoomPreviewDialogState();
}

class _RoomPreviewDialogState extends State<RoomPreviewDialog> {
  late TextEditingController _nameController;
  RoomPreviewModel? _preview;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultUsername);
    _loadPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prev = await SocketService.instance.previewInviteLink(widget.inviteToken);
      if (mounted) {
        setState(() {
          _preview = prev;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name to join.')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final room = await SocketService.instance.joinRoomByInvite(widget.inviteToken, name);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LobbyScreen(
              roomCode: room.roomCode,
              category: room.category,
              itemCount: room.totalItems,
              username: name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.surfaceLight),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accent),
                      SizedBox(height: 16),
                      Text(
                        'Verifying Invitation...',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Invitation Unavailable',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  )
                : _buildPreviewContent(),
      ),
    );
  }

  Widget _buildPreviewContent() {
    final prev = _preview!;
    final canJoin = prev.isOpen && prev.status == 'AVAILABLE';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gavel_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auction Invitation',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Room ${prev.roomCode}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: canJoin ? AppTheme.success.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prev.status,
                  style: TextStyle(
                    color: canJoin ? AppTheme.success : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildInfoRow('Host', prev.hostUsername),
                const Divider(height: 16, color: Colors.white10),
                _buildInfoRow('Category', prev.category),
                const Divider(height: 16, color: Colors.white10),
                _buildInfoRow('Match Items', '${prev.itemCount} Items'),
                const Divider(height: 16, color: Colors.white10),
                _buildInfoRow('Timer Duration', '${prev.timerDuration}s per item'),
                const Divider(height: 16, color: Colors.white10),
                _buildInfoRow('Capacity', '${prev.currentPlayersCount} / ${prev.maxPlayers} Players'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (canJoin) ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Your Display Name',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isJoining ? null : _handleJoin,
              child: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Confirm & Join Auction', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                prev.status == 'FULL'
                    ? 'This room has reached maximum capacity (8 players).'
                    : prev.status == 'IN_PROGRESS'
                        ? 'The auction has already started.'
                        : 'This invitation is no longer active.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
