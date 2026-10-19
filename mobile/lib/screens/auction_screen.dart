import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/auction_state_model.dart';
import '../models/player_model.dart';
import '../services/socket_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/stat_badge.dart';
import 'results_screen.dart';

class AuctionScreen extends StatefulWidget {
  final String categoryDisplayName;

  const AuctionScreen({
    super.key,
    required this.categoryDisplayName,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  bool _isActionBusy = false;
  String? _lastLeadingBidderId;
  String? _lastPhase;
  int _lastTimerSeconds = -1;

  @override
  void initState() {
    super.initState();
    SocketService.instance.auctionNotifier.addListener(_onAuctionStateChanged);
  }

  @override
  void dispose() {
    SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
    super.dispose();
  }

  void _onAuctionStateChanged() {
    final state = SocketService.instance.auctionNotifier.value;
    if (state == null) return;

    final currentSocketId = SocketService.instance.socketId;

    // Timer countdown warning SFX
    if (state.phase == 'BIDDING' && state.timerSecondsRemaining <= 5 && state.timerSecondsRemaining > 0) {
      if (state.timerSecondsRemaining != _lastTimerSeconds) {
        _lastTimerSeconds = state.timerSecondsRemaining;
        AudioService().playSfx(SfxType.timerWarning);
        AudioService().triggerHaptic();
      }
    }

    // Bidder transition SFX
    if (state.leadingBidderId != _lastLeadingBidderId) {
      if (state.leadingBidderId == currentSocketId) {
        AudioService().playSfx(SfxType.highestBidder);
      } else if (_lastLeadingBidderId == currentSocketId && state.leadingBidderId != null) {
        AudioService().playSfx(SfxType.outbid);
        AudioService().triggerHaptic();
      }
      _lastLeadingBidderId = state.leadingBidderId;
    }

    // Phase transition SFX
    if (state.phase != _lastPhase) {
      if (state.phase == 'SOLD') {
        AudioService().playSfx(SfxType.itemSold);
      } else if (state.phase == 'UNSOLD') {
        AudioService().playSfx(SfxType.itemUnsold);
      } else if (state.phase == 'ITEM_ANNOUNCED') {
        AudioService().playSfx(SfxType.itemAnnounced);
      }
      _lastPhase = state.phase;
    }

    // Match Completed
    if (state.phase == 'COMPLETED' && mounted) {
      if (state.standings.isNotEmpty) {
        final winner = state.standings.first;
        if (winner.playerId == currentSocketId) {
          AudioService().playSfx(SfxType.matchVictory);
        } else {
          AudioService().playSfx(SfxType.matchTie);
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            categoryName: widget.categoryDisplayName,
            standings: state.standings,
          ),
        ),
      );
    }
  }

  Future<void> _placeBid(int nextBidAmount) async {
    final settings = SettingsService();

    // Check if confirm bid dialog is enabled
    final state = SocketService.instance.auctionNotifier.value;
    final currentSocketId = SocketService.instance.socketId;
    final myPlayer = state?.players.firstWhere(
      (p) => p.id == currentSocketId,
      orElse: () => const PlayerModel(id: '', name: 'You', budget: 1000),
    );

    if (settings.confirmBidDialog && (myPlayer != null && nextBidAmount > (myPlayer.budget * 0.5))) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Confirm High Bid', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text(
            'Are you sure you want to place a bid of \$$nextBidAmount? (This represents over 50% of your remaining budget \$${myPlayer.budget}).',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFIRM BID'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isActionBusy = true;
    });

    try {
      await SocketService.instance.placeBid(nextBidAmount);
      AudioService().playSfx(SfxType.bidAccepted);
    } catch (e) {
      if (!mounted) return;
      AudioService().playSfx(SfxType.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
        });
      }
    }
  }

  Future<void> _passItem() async {
    setState(() {
      _isActionBusy = true;
    });

    try {
      await SocketService.instance.passItem();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You passed on this item.'),
          backgroundColor: AppTheme.surfaceLight,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
        });
      }
    }
  }

  Future<bool> _handleLeaveMatch(BuildContext context) async {
    final settings = SettingsService();
    if (settings.confirmLeaveMatch) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Leave Match?', style: TextStyle(color: AppTheme.textPrimary)),
          content: const Text(
            'Are you sure you want to forfeit and leave the active auction match?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LEAVE MATCH'),
            ),
          ],
        ),
      );
      if (confirm != true) return false;
    }
    await SocketService.instance.leaveRoom();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuctionStateModel?>(
      valueListenable: SocketService.instance.auctionNotifier,
      builder: (context, state, child) {
        final currentItem = state?.currentItem;
        final currentBid = state?.currentBid ?? 0;
        final minNextBid = state?.minNextBid ?? 0;
        final leadingBidderName = state?.leadingBidderName ?? 'None';
        final isBiddingOpen = state?.phase == 'BIDDING';
        final currentSocketId = SocketService.instance.socketId;

        final myPlayer = state?.players.firstWhere(
          (p) => p.id == currentSocketId,
          orElse: () => const PlayerModel(id: '', name: 'You', budget: 1000),
        );

        final myRemainingBudget = myPlayer?.budget ?? 1000;
        final hasPassed = state?.passedPlayerIds.contains(currentSocketId) ?? false;
        final isLeading = state?.leadingBidderId == currentSocketId;
        final gameModeStr = (state?.gameMode == 'POWER_COMPARISON')
            ? 'Mode A: Power Comparison'
            : 'Mode B: Team Challenge';

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldLeave = await _handleLeaveMatch(context);
            if (shouldLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PowerBid Live Arena', style: const TextStyle(fontSize: 16)),
                Text(gameModeStr, style: const TextStyle(fontSize: 11, color: AppTheme.accent)),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.tag_rounded, size: 14, color: AppTheme.accent),
                  label: Text('Item ${(state?.currentItemIndex ?? 0) + 1}/${state?.totalItems ?? 0}'),
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Progress & Timer Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.surfaceLight),
                        ),
                        child: Text(
                          'ITEM ${(state?.currentItemIndex ?? 0) + 1} OF ${state?.totalItems ?? 10}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Server Countdown Timer Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (state?.timerSecondsRemaining ?? 15) <= 5
                                ? AppTheme.error
                                : AppTheme.warning,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: (state?.timerSecondsRemaining ?? 15) <= 5
                                  ? AppTheme.error
                                  : AppTheme.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${state?.timerSecondsRemaining ?? 15}s',
                              style: TextStyle(
                                color: (state?.timerSecondsRemaining ?? 15) <= 5
                                    ? AppTheme.error
                                    : AppTheme.warning,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phase Banner
                  if (state?.phase == 'ITEM_ANNOUNCED')
                    _buildStatusBanner('GET READY FOR NEXT ITEM', AppTheme.accent)
                  else if (state?.phase == 'SOLD')
                    _buildStatusBanner('SOLD TO $leadingBidderName FOR \$$currentBid!', AppTheme.success)
                  else if (state?.phase == 'UNSOLD')
                    _buildStatusBanner('ITEM UNSOLD (NO BIDS)', AppTheme.warning),

                  const Spacer(),

                  // Text-Only Item Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          (currentItem?.category ?? 'CATALOG').toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currentItem?.displayName ?? 'Auction Item',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Base Price: \$${currentItem?.basePrice ?? 0}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Live Bidding Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: StatBadge(
                          label: 'CURRENT BID',
                          value: currentBid > 0 ? '\$$currentBid' : 'No Bids',
                          icon: Icons.gavel_rounded,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatBadge(
                          label: 'HIGHEST BIDDER',
                          value: leadingBidderName,
                          icon: Icons.person_pin_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // User Budget & Pass Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.success, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              hasPassed ? 'STATUS: PASSED ON ITEM' : 'YOUR REMAINING BUDGET',
                              style: TextStyle(
                                color: hasPassed ? AppTheme.warning : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$$myRemainingBudget',
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Controls Row (PASS & BID Buttons)
                  Row(
                    children: [
                      // PASS Button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: (isBiddingOpen && !hasPassed && !_isActionBusy) ? _passItem : null,
                          icon: const Icon(Icons.block_rounded, size: 18),
                          label: const Text('PASS'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // BID Button
                      Expanded(
                        flex: 3,
                        child: CustomButton(
                          label: isLeading
                              ? 'YOU ARE HIGHEST (\$$currentBid)'
                              : (minNextBid <= myRemainingBudget
                                  ? 'BID \$$minNextBid'
                                  : 'INSUFFICIENT BUDGET'),
                          icon: Icons.gavel_rounded,
                          isLoading: _isActionBusy,
                          onPressed: (isBiddingOpen &&
                                  !hasPassed &&
                                  !isLeading &&
                                  minNextBid <= myRemainingBudget)
                              ? () => _placeBid(minNextBid)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildStatusBanner(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
