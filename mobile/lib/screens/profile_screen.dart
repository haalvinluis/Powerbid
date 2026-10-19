import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../widgets/stat_badge.dart';
import 'match_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int initialTab;

  const ProfileScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _achievementsList = [];
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prof = await SocketService.instance.getPlayerProfile();
      final ach = await SocketService.instance.getAchievements();
      final hist = await SocketService.instance.getMatchHistory(limit: 5);

      if (mounted) {
        setState(() {
          _profileData = prof;
          _achievementsList = ach;
          _historyList = hist;
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

  void _showEditUsernameDialog() {
    _usernameController.text = _profileData?['username'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Update Player Username', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'New Username (3-20 chars)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _isUpdatingName ? null : _handleUpdateUsername,
              child: const Text('Save Username'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdateUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isUpdatingName = true;
    });

    final res = await SocketService.instance.updateUsername(newName);
    if (mounted) {
      setState(() {
        _isUpdatingName = false;
      });
      Navigator.pop(context);

      if (res['success'] == true && res['profile'] != null) {
        setState(() {
          _profileData = res['profile'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated successfully!'), backgroundColor: AppTheme.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to update username.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _profileData?['username'] ?? 'GuestPlayer';
    final avatarText = _profileData?['avatarText'] ?? '⚡';
    final matchesPlayed = _profileData?['matchesPlayed'] ?? 0;
    final matchesWon = _profileData?['matchesWon'] ?? 0;
    final matchesTied = _profileData?['matchesTied'] ?? 0;
    final winRate = _profileData?['winRate'] ?? 0;
    final totalPurchased = _profileData?['totalCharactersPurchased'] ?? 0;
    final unlockedCount = _profileData?['achievementsUnlockedCount'] ?? 0;
    final totalAchCount = _profileData?['totalAchievementsCount'] ?? 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile & Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchProfileData,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // User Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              avatarText,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        username,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AppTheme.accent, size: 20),
                                      onPressed: _showEditUsernameDialog,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.badge_rounded, size: 14, color: AppTheme.accent),
                                          const SizedBox(width: 6),
                                          Text(
                                            _profileData?['publicPlayerId'] ?? _profileData?['playerId'] ?? 'PB-PENDING',
                                            style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        final idToCopy = _profileData?['publicPlayerId'] ?? _profileData?['playerId'] ?? '';
                                        if (idToCopy.isNotEmpty) {
                                          Clipboard.setData(ClipboardData(text: idToCopy));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Player ID copied to clipboard!'),
                                              backgroundColor: AppTheme.accent,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.copy_rounded, size: 13, color: AppTheme.textSecondary),
                                            SizedBox(width: 4),
                                            Text(
                                              'Copy ID',
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('🪙', style: TextStyle(fontSize: 13)),
                                          const SizedBox(width: 5),
                                          ValueListenableBuilder<int>(
                                            valueListenable: AuthService.instance.coinBalanceNotifier,
                                            builder: (context, balance, child) => Text(
                                              '${_profileData?['coinBalance'] ?? balance} Coins',
                                              style: const TextStyle(
                                                color: AppTheme.warning,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: AuthService.instance.isLoggedInNotifier,
                                      builder: (context, isLoggedIn, _) {
                                        return InkWell(
                                          onTap: () => _showAuthModal(context),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isLoggedIn
                                                  ? AppTheme.success.withValues(alpha: 0.15)
                                                  : AppTheme.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isLoggedIn
                                                    ? AppTheme.success.withValues(alpha: 0.5)
                                                    : AppTheme.accent.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isLoggedIn ? Icons.verified_user_rounded : Icons.link_rounded,
                                                  size: 13,
                                                  color: isLoggedIn ? AppTheme.success : AppTheme.accent,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isLoggedIn ? 'Registered' : 'Link Account',
                                                  style: TextStyle(
                                                    color: isLoggedIn ? AppTheme.success : AppTheme.accent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Selector
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.accent,
                      labelColor: AppTheme.accent,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        const Tab(text: 'STATS & ACHIEVEMENTS'),
                        const Tab(text: 'RECENT HISTORY'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // STATS & ACHIEVEMENTS TAB
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stats Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: StatBadge(
                                        label: 'MATCHES PLAYED',
                                        value: '$matchesPlayed',
                                        icon: Icons.sports_esports_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: StatBadge(
                                        label: 'MATCHES WON',
                                        value: '$matchesWon',
                                        icon: Icons.emoji_events_rounded,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: StatBadge(
                                        label: 'WIN RATE',
                                        value: '$winRate%',
                                        icon: Icons.trending_up_rounded,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: StatBadge(
                                        label: 'MATCHES TIED',
                                        value: '$matchesTied',
                                        icon: Icons.handshake_rounded,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StatBadge(
                                  label: 'TOTAL CHARACTERS PURCHASED',
                                  value: '$totalPurchased Text Characters',
                                  icon: Icons.shopping_bag_rounded,
                                ),

                                const SizedBox(height: 24),

                                // Achievements Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'ACHIEVEMENTS',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      '$unlockedCount / $totalAchCount Unlocked',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Achievements List
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _achievementsList.length,
                                  itemBuilder: (context, index) {
                                    final ach = _achievementsList[index];
                                    final title = ach['title'] ?? 'Achievement';
                                    final desc = ach['description'] ?? '';
                                    final iconText = ach['iconText'] ?? '🏆';
                                    final isUnlocked = ach['isUnlocked'] == true;
                                    final progress = ach['progress'] ?? 0;
                                    final threshold = ach['threshold'] ?? 1;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isUnlocked ? AppTheme.warning : AppTheme.surfaceLight,
                                          width: isUnlocked ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isUnlocked
                                                ? AppTheme.warning.withValues(alpha: 0.2)
                                                : AppTheme.surfaceLight,
                                            child: Text(
                                              iconText,
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: isUnlocked ? Colors.white : Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  desc,
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                LinearProgressIndicator(
                                                  value: threshold > 0 ? (progress / threshold).clamp(0.0, 1.0) : 0,
                                                  backgroundColor: AppTheme.surfaceLight,
                                                  color: isUnlocked ? AppTheme.warning : AppTheme.primary,
                                                  minHeight: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            isUnlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                                            color: isUnlocked ? AppTheme.warning : AppTheme.textSecondary,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // RECENT HISTORY TAB
                          _historyList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 48),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No Recent Matches Played',
                                        style: TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _historyList.length,
                                        itemBuilder: (context, index) {
                                          final rec = _historyList[index];
                                          final category = (rec['category'] ?? 'Cricket').toString().toUpperCase();
                                          final winnerName = rec['winnerName'] ?? 'Unknown';
                                          final itemsCount = rec['itemCount'] ?? 10;
                                          final completedAt = rec['completedAt'] ?? '';
                                          final dateStr = completedAt.length >= 10 ? completedAt.substring(0, 10) : 'Recent';

                                          return Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surface,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.surfaceLight),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      category,
                                                      style: const TextStyle(
                                                        color: AppTheme.textPrimary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Winner: $winnerName • $dateStr',
                                                      style: const TextStyle(
                                                        color: AppTheme.textSecondary,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '$itemsCount Items',
                                                  style: const TextStyle(
                                                    color: AppTheme.accent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.history_edu_rounded),
                                      label: const Text('View Full Match History Log'),
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

  void _showAuthModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const _AuthModalWidget(),
      ),
    ).then((_) {
      _fetchProfileData();
    });
  }
}

class _AuthModalWidget extends StatefulWidget {
  const _AuthModalWidget();

  @override
  State<_AuthModalWidget> createState() => _AuthModalWidgetState();
}

class _AuthModalWidgetState extends State<_AuthModalWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoginMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = _isLoginMode
          ? await AuthService.instance.login(email: email, password: password)
          : await AuthService.instance.linkGuest(email: email, password: password);

      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLoginMode ? 'Logged in successfully!' : 'Account linked successfully!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['error'] ?? 'Authentication failed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error. Please try again.';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out. Reverted to guest session.'),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedInNotifier.value;
    final userEmail = AuthService.instance.currentUserEmailNotifier.value;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: isLoggedIn
            ? _buildLoggedInContent(userEmail)
            : _buildAuthFormContent(),
      ),
    );
  }

  Widget _buildLoggedInContent(String? email) {
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
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registered Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email ?? 'Protected User',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: AppTheme.accent, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your coin balance, stats, friends, and match history are securely stored in PostgreSQL.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
            foregroundColor: Colors.redAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                )
              : const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Log Out (Switch to Guest)'),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildAuthFormContent() {
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
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLoginMode = false;
                  _errorMessage = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isLoginMode ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isLoginMode ? AppTheme.accent : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    'Link Guest Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: !_isLoginMode ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLoginMode = true;
                  _errorMessage = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isLoginMode ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isLoginMode ? AppTheme.accent : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    'Log In Existing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _isLoginMode ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          !_isLoginMode
              ? 'Register with your email to protect your stats and coins permanently.'
              : 'Sign in to access your registered profile and coin wallet.',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accent, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surfaceLight,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Password (min 8 chars, letters & numbers)',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surfaceLight,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  !_isLoginMode ? 'Link Account & Save Data' : 'Log In',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
