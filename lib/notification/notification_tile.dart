import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/app_notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static final _dateFormat = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconData(notification.type);
    final isUnread = !notification.isRead;

    Widget child = InkWell(
      onTap: onTap,
      child: Container(
        color:
            isUnread ? AppTheme.gold.withValues(alpha: 0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppTheme.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateFormat.format(notification.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          tooltip: 'Supprimer',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.negative,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onDelete != null) {
      child = Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete?.call(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: AppTheme.negative,
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        child: child,
      );
    }

    return child;
  }

  (IconData, Color) _iconData(NotificationType type) {
    return switch (type) {
      NotificationType.transactionReceived => (
          Icons.arrow_downward_rounded,
          AppTheme.positive
        ),
      NotificationType.transactionSent => (
          Icons.arrow_upward_rounded,
          AppTheme.negative
        ),
      NotificationType.transactionConfirmationRequired => (
          Icons.pending_rounded,
          AppTheme.warning
        ),
      NotificationType.auctionOutbid => (
          Icons.gavel_rounded,
          AppTheme.negative
        ),
      NotificationType.auctionWon => (
          Icons.emoji_events_rounded,
          AppTheme.gold
        ),
      NotificationType.auctionEnded => (Icons.gavel_rounded, Colors.grey),
      NotificationType.loanRequested => (
          Icons.handshake_rounded,
          AppTheme.gold
        ),
      NotificationType.loanAccepted => (
          Icons.check_circle_rounded,
          AppTheme.positive
        ),
      NotificationType.loanRejected => (
          Icons.cancel_rounded,
          AppTheme.negative
        ),
      NotificationType.loanRepaid => (Icons.payment_rounded, AppTheme.positive),
      NotificationType.loanOverdue => (
          Icons.warning_rounded,
          AppTheme.negative
        ),
      NotificationType.marketplacePurchase => (
          Icons.storefront_rounded,
          AppTheme.gold
        ),
      NotificationType.accountApproved => (
          Icons.verified_rounded,
          AppTheme.positive
        ),
      NotificationType.accountRejected => (
          Icons.block_rounded,
          AppTheme.negative
        ),
      NotificationType.adminTax => (Icons.percent_rounded, AppTheme.negative),
      NotificationType.adminReward => (Icons.star_rounded, AppTheme.gold),
      NotificationType.system => (Icons.info_rounded, Colors.grey),
    };
  }
}
