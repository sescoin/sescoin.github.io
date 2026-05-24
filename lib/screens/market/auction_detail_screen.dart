import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../providers/auction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';

class AuctionDetailScreen extends ConsumerStatefulWidget {
  const AuctionDetailScreen({super.key, required this.auctionId});
  final String auctionId;

  @override
  ConsumerState<AuctionDetailScreen> createState() =>
      _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends ConsumerState<AuctionDetailScreen> {
  final _amountCtrl = TextEditingController();
  bool _checkedExpired = false;
  DateTime _now = DateTime.now();
  Timer? _timer;
  static const _emojiChoices = ['🔥', '😎', '👑', '🚀', '💎', '😈'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    Future.microtask(
      () => ref.read(auctionServiceProvider).finalizeExpiredAuctions(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeBid(double minBid) async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount < minBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offre minimum : ${minBid.toStringAsFixed(2)} SC'),
        ),
      );
      return;
    }

    try {
      await ref.read(bidProvider.notifier).placeBid(
            auctionId: widget.auctionId,
            amount: amount,
          );
      _amountCtrl.clear();
      if (mounted) {
        ref.invalidate(auctionBidsProvider(widget.auctionId));
        ref.invalidate(auctionStreamProvider(widget.auctionId));
        ref.invalidate(activeAuctionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enchère placée'),
            backgroundColor: AppTheme.positive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _setWinnerEmoji(String emoji) async {
    try {
      await ref.read(auctionServiceProvider).setWinnerEmoji(
            auctionId: widget.auctionId,
            emoji: emoji,
          );
      ref.invalidate(auctionStreamProvider(widget.auctionId));
      ref.invalidate(activeAuctionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auctionAsync = ref.watch(auctionStreamProvider(widget.auctionId));
    final bidsAsync = ref.watch(auctionBidsProvider(widget.auctionId));
    final bidState = ref.watch(bidProvider);
    final userId = ref.watch(currentUserIdProvider) ?? '';

    return auctionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
          message: e.toString(),
          onRetry: () => ref.invalidate(auctionStreamProvider(widget.auctionId)),
        ),
      ),
      data: (auction) {
        final remaining = auction.endsAt.difference(_now);
        final liveRemaining = remaining.isNegative ? Duration.zero : remaining;

        if (!_checkedExpired && auction.isActive && liveRemaining == Duration.zero) {
          _checkedExpired = true;
          Future.microtask(
            () => ref.read(auctionServiceProvider).finalizeExpiredAuctions(),
          );
        }

        final isCurrentWinner = auction.currentWinnerId == userId;

        return Scaffold(
          appBar: AppBar(title: Text(auction.itemName)),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (auction.itemImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          auction.itemImageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (auction.itemDescription.trim().isNotEmpty) ...[
                      Text(
                        auction.itemDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Stat(
                                  label: 'Prix actuel',
                                  value:
                                      '${auction.currentPrice.toStringAsFixed(2)} SC',
                                  color: AppTheme.gold,
                                ),
                                _Stat(
                                  label: 'Offres',
                                  value: '${auction.bidCount}',
                                ),
                                _Stat(
                                  label: 'Temps restant',
                                  value: _formatDuration(liveRemaining),
                                ),
                              ],
                            ),
                            if (auction.currentWinnerUsername != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  UserAvatar(
                                    username: auction.currentWinnerUsername!,
                                    radius: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Dernier enchérisseur : @${auction.currentWinnerUsername}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (auction.currentWinnerEmoji != null)
                                    Text(
                                      auction.currentWinnerEmoji!,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (auction.isActive && !isCurrentWinner) ...[
                      Text(
                        'Placer une offre',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Min. ${auction.minimumNextBid.toStringAsFixed(2)} SC',
                                suffixText: 'SC',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: bidState.isLoading
                                ? null
                                : () => _placeBid(auction.minimumNextBid),
                            icon: bidState.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.gavel_rounded, size: 18),
                            label: const Text('Enchérir'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ] else if (isCurrentWinner) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.positive.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Vous êtes actuellement en tête',
                          style: TextStyle(
                            color: AppTheme.positive,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choisissez un emoji à afficher sur l’enchère',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _emojiChoices.map((emoji) {
                          final selected = auction.currentWinnerEmoji == emoji;
                          return ChoiceChip(
                            selected: selected,
                            label: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            onSelected: (_) => _setWinnerEmoji(emoji),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Historique des offres',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    bidsAsync.when(
                      loading: () => const InlineLoader(),
                      error: (e, _) => ErrorRetry(
                        message: 'Impossible de charger les offres',
                        onRetry: () => ref.invalidate(
                          auctionBidsProvider(widget.auctionId),
                        ),
                      ),
                      data: (bids) => bids.isEmpty
                          ? const EmptyState(
                              icon: Icons.gavel_rounded,
                              title: 'Aucune offre',
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: bids.length,
                              itemBuilder: (context, i) {
                                final bid = bids[i];
                                return ListTile(
                                  leading: UserAvatar(
                                    username: bid.bidderUsername,
                                    radius: 18,
                                  ),
                                  title: Text('@${bid.bidderUsername}'),
                                  trailing: Text(
                                    '${bid.amount.toStringAsFixed(2)} SC',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: i == 0 ? AppTheme.gold : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              if (bidState.isLoading)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 4),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Traitement de l’offre',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return 'Terminée';
    if (duration.inDays > 0) {
      return '${duration.inDays}j ${duration.inHours.remainder(24)}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
