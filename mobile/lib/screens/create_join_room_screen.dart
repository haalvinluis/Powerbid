import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/section_header.dart';
import '../widgets/room_preview_dialog.dart';
import '../config/app_config.dart';
import 'lobby_screen.dart';

class CreateJoinRoomScreen extends StatefulWidget {
  final String selectedCategory;
  final String gameMode;
  final int itemCount;

  const CreateJoinRoomScreen({
    super.key,
    this.selectedCategory = 'cricket',
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    this.itemCount = 10,
  });

  @override
  State<CreateJoinRoomScreen> createState() => _CreateJoinRoomScreenState();
}

class _CreateJoinRoomScreenState extends State<CreateJoinRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _usernameController =
      TextEditingController(text: 'Player_1');
  final TextEditingController _serverUrlController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _serverUrlController.text = SocketService.instance.serverUrl;
    SocketService.instance.connect();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    _usernameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    final username = _usernameController.text.trim().isEmpty
        ? 'HostPlayer'
        : _usernameController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SocketService.instance.createRoom(
        username: username,
        category: widget.selectedCategory,
        gameMode: widget.gameMode,
        itemCount: widget.itemCount,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: room.roomCode,
            category: widget.selectedCategory,
            itemCount: widget.itemCount,
            username: username,
          ),
        ),
      );
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
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoinRoom() async {
    final username = _usernameController.text.trim().isEmpty
        ? 'GuestPlayer'
        : _usernameController.text.trim();
    final input = _roomCodeController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-character room code or invite link')),
      );
      return;
    }

    // Support deep link or invite token input
    if (input.contains('/invite/') || input.length > 8) {
      final token = input.contains('/invite/') ? input.split('/invite/').last.split('?').first : input;
      RoomPreviewDialog.show(context, inviteToken: token, defaultUsername: username);
      return;
    }

    final roomCode = input;

    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SocketService.instance.joinRoom(
        username: username,
        roomCode: roomCode,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: room.roomCode,
            category: room.category,
            itemCount: room.totalItems,
            username: username,
          ),
        ),
      );
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Multiplayer Room'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(text: 'Create Room'),
            Tab(text: 'Join Room'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username Input Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeader(
                    title: 'Player Profile',
                    subtitle: 'Set your name for room display',
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: SocketService.instance.isConnectedNotifier,
                    builder: (context, isConnected, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isConnected ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConnected ? AppTheme.success : AppTheme.error,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: isConnected ? AppTheme.success : AppTheme.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected ? 'Online' : 'Connecting...',
                              style: TextStyle(
                                color: isConnected ? AppTheme.success : AppTheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your player name',
                  prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
              ),
              const SizedBox(height: 14),

              // Server URL Config Input
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                onChanged: (val) => SocketService.instance.updateServerUrl(val),
                decoration: InputDecoration(
                  labelText: 'Game Server URL',
                  hintText: AppConfig.defaultServerUrl,
                  helperText: 'Environment: ${AppConfig.environment.toUpperCase()} • ${AppConfig.defaultServerUrl}',
                  helperStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  prefixIcon: const Icon(Icons.dns_rounded, color: AppTheme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 240,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Create Room Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Config: ${widget.selectedCategory.toUpperCase()} (${widget.itemCount} Items)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Mode: ${widget.gameMode == "POWER_COMPARISON" ? "Mode A: Power Comparison" : "Mode B: Auction Team Challenge"}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        CustomButton(
                          label: 'Create Online Room',
                          icon: Icons.add_circle_outline_rounded,
                          isLoading: _isLoading,
                          onPressed: _handleCreateRoom,
                        ),
                      ],
                    ),

                    // Join Room Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _roomCodeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Enter 6-Character Room Code',
                            hintText: 'X7K9P2',
                            prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.accent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: AppTheme.surface,
                          ),
                        ),
                        const Spacer(),
                        CustomButton(
                          label: 'Join Online Room',
                          icon: Icons.login_rounded,
                          isLoading: _isLoading,
                          onPressed: _handleJoinRoom,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
