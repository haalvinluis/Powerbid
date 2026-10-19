import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../models/friend_model.dart';

class FriendsScreen extends StatefulWidget {
  final int initialTab;

  const FriendsScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _incomingRequests = [];
  List<FriendRequestModel> _outgoingRequests = [];

  bool _isLoading = true;
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _searchResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await SocketService.instance.getFriendsList();
      final reqs = await SocketService.instance.getFriendRequests();

      if (mounted) {
        setState(() {
          _friends = friends;
          _incomingRequests = reqs['incoming'] ?? [];
          _outgoingRequests = reqs['outgoing'] ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim().toUpperCase();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final res = await SocketService.instance.searchPlayerById(query);
      if (mounted) {
        setState(() {
          _isSearching = false;
          if (res['success'] == true && res['player'] != null) {
            _searchResult = Map<String, dynamic>.from(res['player']);
          } else {
            _searchError = res['error'] ?? 'Player not found.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _sendFriendRequest(String publicPlayerId) async {
    try {
      final res = await SocketService.instance.sendFriendRequest(publicPlayerId);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request sent!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _loadData();
          _handleSearch(); // Refresh search card status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to send request.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    try {
      final res = await SocketService.instance.respondFriendRequest(requestId, action);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(action == 'ACCEPT' ? 'Friend request accepted!' : 'Friend request declined.'),
              backgroundColor: action == 'ACCEPT' ? AppTheme.success : AppTheme.surfaceLight,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to respond.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      final res = await SocketService.instance.cancelFriendRequest(requestId);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request cancelled.'),
              backgroundColor: AppTheme.surfaceLight,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to cancel request.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveFriend(FriendModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove Friend', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to remove ${friend.username} (${friend.publicPlayerId}) from your friends list?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await SocketService.instance.removeFriend(friend.publicPlayerId);
        if (mounted) {
          if (res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed ${friend.username} from friends.'),
                backgroundColor: AppTheme.surfaceLight,
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['error'] ?? 'Failed to remove friend.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRequests = _incomingRequests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends & Players'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'MY FRIENDS (${_friends.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('REQUESTS'),
                  if (totalRequests > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$totalRequests',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'FIND FRIENDS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMyFriendsTab(),
                  _buildRequestsTab(),
                  _buildFindFriendsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMyFriendsTab() {
    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'No Friends Added Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the Find Friends tab to search players by their unique Player ID (e.g. PB-XXXXXX).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('Find Friends'),
                onPressed: () => _tabController.animateTo(2),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (ctx, idx) {
          final friend = _friends[idx];
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.surfaceLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          friend.avatarText,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.isOnline ? AppTheme.success : AppTheme.textSecondary,
                            border: Border.all(color: AppTheme.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              friend.username,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (friend.currentRoomCode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'In ${friend.currentRoomCode}',
                                  style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              friend.publicPlayerId,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${friend.matchesWon}W (${friend.winRate}%)',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                    color: AppTheme.surface,
                    onSelected: (val) {
                      if (val == 'copy_id') {
                        Clipboard.setData(ClipboardData(text: friend.publicPlayerId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Player ID copied to clipboard!')),
                        );
                      } else if (val == 'remove') {
                        _confirmRemoveFriend(friend);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'copy_id',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 16, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text('Copy Player ID', style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_rounded, size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Remove Friend', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_incomingRequests.isEmpty && _outgoingRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mail_outline_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'No Pending Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incoming and outgoing friend requests will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_incomingRequests.isNotEmpty) ...[
            Text(
              'RECEIVED REQUESTS (${_incomingRequests.length})',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            ..._incomingRequests.map((req) {
              return Card(
                color: AppTheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.surfaceLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          req.senderAvatarText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.senderUsername,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              req.senderPublicId,
                              style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 30),
                        tooltip: 'Accept',
                        onPressed: () => _respondToRequest(req.requestId, 'ACCEPT'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 30),
                        tooltip: 'Decline',
                        onPressed: () => _respondToRequest(req.requestId, 'DECLINE'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
          if (_outgoingRequests.isNotEmpty) ...[
            Text(
              'SENT REQUESTS (${_outgoingRequests.length})',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            ..._outgoingRequests.map((req) {
              return Card(
                color: AppTheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.surfaceLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.surfaceLight,
                        child: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.receiverUsername,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              req.receiverPublicId,
                              style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _cancelRequest(req.requestId),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFindFriendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const Text(
                  'Search by Player ID',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every PowerBid player has a unique non-sequential ID (e.g. PB-A7K9X2). Ask your friend for their ID and enter it below.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        decoration: InputDecoration(
                          hintText: 'PB-XXXXXX',
                          hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          prefixIcon: const Icon(Icons.badge_rounded, color: AppTheme.accent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _handleSearch(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSearching ? null : _handleSearch,
                      child: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_searchError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (_searchResult != null) ...[
            const Text(
              'SEARCH RESULT',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            _searchResult!['avatarText']?.toString() ?? '⚡',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _searchResult!['username']?.toString() ?? 'Player',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _searchResult!['publicPlayerId']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _searchResult!['isOnline'] == true ? AppTheme.success : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _searchResult!['isOnline'] == true ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      color: _searchResult!['isOnline'] == true ? AppTheme.success : AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppTheme.surfaceLight),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCol('MATCHES', '${_searchResult!['matchesPlayed'] ?? 0}'),
                        _buildStatCol('WINS', '${_searchResult!['matchesWon'] ?? 0}'),
                        _buildStatCol('WIN RATE', '${_searchResult!['winRate'] ?? 0}%'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSearchResultActionButton(_searchResult!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSearchResultActionButton(Map<String, dynamic> player) {
    final status = player['friendshipStatus']?.toString() ?? 'NONE';
    final targetId = player['publicPlayerId']?.toString() ?? '';

    if (status == 'FRIENDS') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
            SizedBox(width: 8),
            Text('Already Friends', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (status == 'REQUEST_SENT') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, color: AppTheme.accent, size: 18),
            SizedBox(width: 8),
            Text('Friend Request Pending', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Send Friend Request'),
          onPressed: () => _sendFriendRequest(targetId),
        ),
      );
    }
  }
}
