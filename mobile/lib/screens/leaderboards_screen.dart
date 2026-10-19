import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _types = ['most_wins', 'win_rate', 'most_items', 'most_matches'];

  Map<String, List<Map<String, dynamic>>> _leaderboardData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchLeaderboard(_types[0]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _fetchLeaderboard(_types[_tabController.index]);
  }

  Future<void> _fetchLeaderboard(String type) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await SocketService.instance.getLeaderboard(type, limit: 15);
      if (mounted) {
        setState(() {
          _leaderboardData[type] = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Arena Leaderboards'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(text: 'Most Wins'),
            Tab(text: 'Win Rate (%)'),
            Tab(text: 'Items Won'),
            Tab(text: 'Matches Played'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: _types.map((type) => _buildLeaderboardTab(type)).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab(String type) {
    final list = _leaderboardData[type] ?? [];

    return Column(
      children: [
        if (type == 'win_rate')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceLight.withValues(alpha: 0.5),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 16),
                SizedBox(width: 8),
                Text(
                  'Minimum 5 completed matches required for Win Rate ranking.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.leaderboard_rounded, color: AppTheme.textSecondary, size: 56),
                          const SizedBox(height: 12),
                          const Text(
                            'No Leaderboard Records Yet',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Complete online room matches to rank on global leaderboards.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final entry = list[index];
                        final rank = entry['rank'] ?? (index + 1);
                        final username = entry['username'] ?? 'Player';
                        final avatarText = entry['avatarText'] ?? '⚡';
                        final detailText = entry['detailText'] ?? '';

                        Color rankColor = AppTheme.surfaceLight;
                        if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
                        else if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
                        else if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: rank <= 3 ? rankColor : AppTheme.surfaceLight,
                              width: rank <= 3 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank Badge
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: rank <= 3 ? rankColor : AppTheme.surfaceLight,
                                child: Text(
                                  '#$rank',
                                  style: TextStyle(
                                    color: rank <= 3 ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Avatar
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  avatarText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Username & detail
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      detailText,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
