import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/auction.dart';
import '../common/amount_display.dart';
import '../common/user_avatar.dart';

class AuctionCard extends StatefulWidget {
  const AuctionCard({
    super.key,
    required this.auction,
    required this.onBid,
    this.isLoading = false,
  });

  final Auction auction;
  final VoidCallback onBid;
  final bool isLoading;

  @override
  State<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<AuctionCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AuctionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auction.id != widget.auction.id ||
        oldWidget.auction.endsAt != widget.auction.endsAt ||
        oldWidget.auction.status != widget.auction.status) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _remaining = widget.auction.timeRemaining;
    if (widget.auction.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _remaining = widget.auction.timeRemaining;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auction = widget.auction;
    final isUrgent = _remaining.inMinutes < 5 && auction.isActive;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (auction.itemImageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                auction.itemImageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 40,
                color: AppTheme.gold,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusBadge(auction: auction),
                    if (auction.isActive)
                      _TimerBadge(
                        remaining: _remaining,
                        isUrgent: isUrgent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  auction.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auction.itemDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offre actuelle',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        AmountDisplay(
                          amount: auction.currentPrice,
                          fontSize: 20,
                        ),
                      ],
                    ),
                    if (auction.currentWinnerUsername != null)
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              username: auction.currentWinnerUsername!,
                              radius: 14,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '@${auction.currentWinnerUsername}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (auction.currentWinnerEmoji != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                auction.currentWinnerEmoji!,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${auction.bidCount} offre${auction.bidCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (auction.isActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.isLoading ? null : widget.onBid,
                      icon: widget.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.gavel_rounded, size: 18),
                      label: Text(
                        'Enchérir (min. ${auction.minimumNextBid.toStringAsFixed(2)} SC)',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.auction});
  final Auction auction;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (auction.status) {
      AuctionStatus.active => ('En cours', AppTheme.positive),
      AuctionStatus.upcoming => ('À venir', AppTheme.gold),
      AuctionStatus.ended => ('Terminée', Colors.grey),
      AuctionStatus.cancelled => ('Annulée', AppTheme.negative),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({
    required this.remaining,
    required this.isUrgent,
  });
  final Duration remaining;
  final bool isUrgent;

  String _format(Duration d) {
    if (d.inDays > 0) {
      return '${d.inDays}j ${d.inHours.remainder(24)}h';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = isUrgent ? AppTheme.negative : Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          _format(remaining),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: isUrgent ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
