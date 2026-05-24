import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/transaction.dart';

class GlobalTransactionTile extends StatelessWidget {
  const GlobalTransactionTile({
    super.key,
    required this.transaction,
    this.onFromTap,
    this.onToTap,
  });

  final Transaction transaction;
  final VoidCallback? onFromTap;
  final VoidCallback? onToTap;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final fromLabel =
        transaction.fromDisplayName ?? transaction.fromUsername ?? 'Inconnu';
    final toLabel =
        transaction.toDisplayName ?? transaction.toUsername ?? 'Inconnu';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TypeBadge(type: transaction.type),
                      if (transaction.paymentMethodLabel != null)
                        _MethodBadge(label: transaction.paymentMethodLabel!),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${transaction.amount.toStringAsFixed(2)} SC',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _UserChip(
                  label: 'De @$fromLabel',
                  onTap: onFromTap,
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18),
                _UserChip(
                  label: 'Vers @$toLabel',
                  onTap: onToTap,
                ),
              ],
            ),
            if (transaction.description != null &&
                transaction.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                transaction.description!.trim(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _dateFormat.format(transaction.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.person_outline_rounded, size: 16),
      label: Text(label),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      TransactionType.transfer => (Icons.swap_horiz_rounded, AppTheme.positive),
      TransactionType.purchase => (Icons.storefront_rounded, AppTheme.gold),
      TransactionType.auction => (Icons.gavel_rounded, const Color(0xFF6C5CE7)),
      TransactionType.loan => (
          Icons.handshake_rounded,
          const Color(0xFF0984E3)
        ),
      TransactionType.reward => (Icons.star_rounded, AppTheme.gold),
      TransactionType.tax => (Icons.percent_rounded, AppTheme.negative),
      TransactionType.adminCredit => (
          Icons.add_circle_rounded,
          AppTheme.positive
        ),
      TransactionType.adminDebit => (
          Icons.remove_circle_rounded,
          AppTheme.negative
        ),
      TransactionType.initialBalance => (
          Icons.account_balance_rounded,
          AppTheme.gold
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Paiement $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
