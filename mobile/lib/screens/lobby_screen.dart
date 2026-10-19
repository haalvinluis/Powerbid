import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/room_model.dart';
import '../models/friend_model.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/player_tile.dart';
import '../widgets/section_header.dart';
import 'auction_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String category;
  final int itemCount;
  final String username;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.category,
    required this.itemCount,
    required this.username,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    SocketService.instance.connect();

    // Listen for auction start broadcast to navigate automatically
    SocketService.instance.auctionNotifier.addListener(_onAuctionStateChanged);
  }

  @override
  void dispose() {
    SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
    super.dispose();
  }

  void _onAuctionStateChanged() {
    final state = SocketService.instance.auctionNotifier.value;
    if (state != null && state.phase != 'LOBBY' && mounted) {
      AudioService().playSfx(SfxType.auctionStart);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuctionScreen(
            categoryDisplayName: widget.category.toUpperCase(),
          ),
        ),
      );
    }
  }

  void _showHostSettingsModal(BuildContext context, RoomModel? room) {
    AudioService().playSfx(SfxType.buttonClick);

    String selectedCategory = room?.category ?? widget.category;
    int selectedItemCount = room?.totalItems ?? widget.itemCount;
    int selectedTimerDuration = room?.timerDuration ?? 15;

    final categories = [
      {'id': 'Cricket', 'name': 'Cricket'},
      {'id': 'Naruto', 'name': 'Naruto'},
      {'id': 'One Piece', 'name': 'One Piece'},
      {'id': 'Dragon Ball', 'name': 'Dragon Ball'},
      {'id': 'Pokemon', 'name': 'Pokémon'},
      {'id': 'Demon Slayer', 'name': 'Demon Slayer'},
      {'id': 'Jujutsu Kaisen', 'name': 'Jujutsu Kaisen'},
      {'id': 'Classic Cartoons', 'name': 'Classic Cartoons'},
      {'id': 'Superheroes', 'name': 'Superheroes'},
      {'id': 'Marvel Avengers', 'name': 'Marvel Avengers'},
      {'id': 'Other Anime', 'name': 'Other Anime'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROOM CUSTOMIZATION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: AppTheme.surfaceLight,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name']!, style: const TextStyle(color: AppTheme.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Auction Item Count', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [5, 10, 25].map((cnt) {
                      final isSel = selectedItemCount == cnt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('$cnt Items'),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          onSelected: (sel) {
                            if (sel) setModalState(() => selectedItemCount = cnt);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Bidding Timer Duration', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [10, 15, 20].map((t) {
                      final isSel = selectedTimerDuration == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('${t}s Timer'),
                          selected: isSel,
                          selectedColor: AppTheme.primary,
                          onSelected: (sel) {
                            if (sel) setModalState(() => selectedTimerDuration = t);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Apply Room Settings',
                    icon: Icons.check,
                    onPressed: () async {
                      AudioService().playSfx(SfxType.buttonClick);
                      Navigator.of(context).pop();
                      try {
                        await SocketService.instance.updateRoomSettings(
                          roomCode: widget.roomCode,
                          category: selectedCategory,
                          itemCount: selectedItemCount,
                          timerDuration: selectedTimerDuration,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Room settings updated successfully.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleStartAuction() async {
    setState(() {
      _isStarting = true;
    });

    try {
      await SocketService.instance.startAuction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _showInviteFriendsSheet(BuildContext context) async {
    AudioService().playSfx(SfxType.buttonClick);
    List<FriendModel> friends = [];
    bool loading = true;
    final Set<String> selectedPublicIds = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading) {
              SocketService.instance.getFriendsList().then((list) {
                if (ctx.mounted) {
                  setModalState(() {
                    friends = list;
                    loading = false;
                  });
                }
              }).catchError((_) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                  });
                }
              });
            }

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
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
                        const Text(
                          'Invite Friends to Room',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (selectedPublicIds.isNotEmpty)
                          Text(
                            '${selectedPublicIds.length} Selected',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose friends to send an instant room invitation notification.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                      )
                    else if (friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'No friends found. Add friends using their Player ID.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (context, idx) {
                            final friend = friends[idx];
                            final isSelected = selectedPublicIds.contains(friend.publicPlayerId);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppTheme.accent,
                              checkColor: Colors.black,
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primary,
                                    child: Text(
                                      friend.avatarText,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.username,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${friend.publicPlayerId} • ${friend.isOnline ? "Online" : "Offline"}',
                                          style: TextStyle(
                                            color: friend.isOnline ? AppTheme.success : AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedPublicIds.add(friend.publicPlayerId);
                                  } else {
                                    selectedPublicIds.remove(friend.publicPlayerId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: selectedPublicIds.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              try {
                                final res = await SocketService.instance.inviteFriendsToRoom(
                                  widget.roomCode,
                                  selectedPublicIds.toList(),
                                );
                                if (context.mounted) {
                                  if (res['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invitations sent to ${res['invitedCount'] ?? selectedPublicIds.length} friends!'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error'] ?? 'Failed to send invitations.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(
                        selectedPublicIds.isEmpty
                            ? 'Select Friends to Invite'
                            : 'Send Invitations (${selectedPublicIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showShareInviteLinkSheet(BuildContext context) async {
    AudioService().playSfx(SfxType.buttonClick);
    String? inviteUrl;
    bool loading = true;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && inviteUrl == null && error == null) {
              SocketService.instance.createInviteLink(widget.roomCode).then((res) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                    if (res['success'] == true && res['inviteUrl'] != null) {
                      inviteUrl = res['inviteUrl'].toString();
                    } else {
                      error = res['error'] ?? 'Failed to generate link.';
                    }
                  });
                }
              }).catchError((e) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                    error = e.toString().replaceAll('Exception: ', '');
                  });
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
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
                    const Text(
                      'Share Room Invitation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Share an unguessable deep link. Friends can view the room preview and join directly.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                      )
                    else if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                inviteUrl ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppTheme.accent, size: 20),
                              tooltip: 'Copy Link',
                              onPressed: () {
                                if (inviteUrl != null) {
                                  Clipboard.setData(ClipboardData(text: inviteUrl!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invitation link copied to clipboard!'),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (inviteUrl != null) {
                                  final msg = 'Join my PowerBid auction! Open this invitation to view the room and join: $inviteUrl';
                                  Share.share(msg, subject: 'PowerBid Auction Invitation');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Share Link', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (inviteUrl != null) {
                                  final msg = 'Join my PowerBid auction! Open this invitation to view the room and join: $inviteUrl';
                                  Share.share(msg, subject: 'PowerBid Auction Invitation');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomModel?>(
      valueListenable: SocketService.instance.currentRoomNotifier,
      builder: (context, room, child) {
        final currentPlayers = room?.players ?? [];
        final hostId = room?.hostId;
        final currentSocketId = SocketService.instance.socketId;
        final isHost = (currentSocketId != null && hostId == currentSocketId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lobby Room'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                onPressed: () async {
                  await SocketService.instance.leaveRoom();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room Code Header Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'ROOM CODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.roomCode,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                                letterSpacing: 6,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.roomCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room code copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text('Category: ${(room?.category ?? widget.category).toUpperCase()}'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            Chip(
                              label: Text('${room?.totalItems ?? widget.itemCount} Items'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            Chip(
                              label: Text('Timer: ${room?.timerDuration ?? 15}s'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Invite Friends', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showInviteFriendsSheet(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Share Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showShareInviteLinkSheet(context),
                              ),
                            ),
                          ],
                        ),
                        if (isHost) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('CUSTOMIZE ROOM SETTINGS', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showHostSettingsModal(context, room),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Players Section Header
                  SectionHeader(
                    title: 'Room Participants (${currentPlayers.length}/8)',
                    subtitle: isHost
                        ? 'You are Host. Start when all players join.'
                        : 'Waiting for host to start match...',
                  ),
                  const SizedBox(height: 12),

                  // Synchronized Player Roster List
                  Expanded(
                    child: currentPlayers.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          )
                        : ListView.builder(
                            itemCount: currentPlayers.length,
                            itemBuilder: (context, index) {
                              final player = currentPlayers[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: PlayerTile(
                                  name: player.name,
                                  isHost: player.isHost,
                                  isMe: player.id == currentSocketId,
                                ),
                              );
                            },
                          ),
                  ),

                  // Host Start Button / Participant Waiting Banner
                  if (isHost)
                    CustomButton(
                      label: 'Start Real-Time Auction',
                      icon: Icons.play_arrow_rounded,
                      isLoading: _isStarting,
                      onPressed: _handleStartAuction,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Waiting for Host to start match...',
                            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
