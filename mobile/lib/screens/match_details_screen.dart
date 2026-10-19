import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic>? initialMatchData;

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    this.initialMatchData,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  Map<String, dynamic>? _matchData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialMatchData != null) {
      _matchData = widget.initialMatchData;
      _isLoading = false;
    } else {
      _fetchMatchDetails();
    }
  }

  Future<void> _fetchMatchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await SocketService.instance.getMatchDetails(widget.matchId);
      if (mounted) {
        if (data != null) {
          setState(() {
            _matchData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Match details record not found.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = (_matchData?['participants'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final winnerName = _matchData?['winnerName'] ?? 'Unknown';
    final category = (_matchData?['category'] ?? 'Cricket').toString().toUpperCase();
    final gameMode = _matchData?['gameMode'] == 'POWER_COMPARISON'
        ? 'Mode A: Power Compare'
        : 'Mode B: Team Challenge';
    final itemCount = _matchData?['itemCount'] ?? 10;
    final isTie = _matchData?['isTie'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result Summary'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchMatchDetails,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Match Summary Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Chip(
                                    label: Text(category),
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                                    labelStyle: const TextStyle(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Chip(
                                    label: Text('$itemCount Items'),
                                    backgroundColor: AppTheme.surfaceLight,
                                    labelStyle: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                gameMode,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    isTie ? Icons.handshake_rounded : Icons.emoji_events_rounded,
                                    color: isTie ? AppTheme.warning : Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isTie ? 'Match Ended in a Tie!' : 'Winner: $winnerName',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'PARTICIPANT BREAKDOWN',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final p = participants[index];
                            final rank = p['rank'] ?? (index + 1);
                            final username = p['username'] ?? 'Player';
                            final itemsWon = p['itemsWon'] ?? 0;
                            final remainingBudget = p['remainingBudget'] ?? 0;
                            final purchased = (p['purchasedItems'] as List<dynamic>?)
                                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                                    .toList() ??
                                [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: rank == 1 ? AppTheme.warning : AppTheme.surfaceLight,
                                  width: rank == 1 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: rank == 1
                                                ? AppTheme.warning
                                                : AppTheme.surfaceLight,
                                            child: Text(
                                              '#$rank',
                                              style: TextStyle(
                                                color: rank == 1 ? Colors.black : Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            username,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text('$itemsWon Won'),
                                            backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                                            labelStyle: const TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '\$$remainingBudget',
                                            style: const TextStyle(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    'Characters Acquired ($itemsWon):',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  purchased.isEmpty
                                      ? const Text(
                                          'No character items purchased in this match.',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: purchased.map((item) {
                                            final itemName = item['itemName'] ?? 'Item';
                                            final price = item['price'] ?? 0;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceLight,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: AppTheme.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                '$itemName • \$$price',
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
