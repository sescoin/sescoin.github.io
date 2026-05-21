import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../common/amount_display.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  static final _dateFormat = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final isCredit = transaction.isCredit(userId);
    final amount = transaction.signedAmount(userId);
    final otherParty = transaction.otherPartyName(userId) ?? 'Inconnu';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Icône type transaction ───────────────────────────────────────
            _TypeIcon(type: transaction.type, isCredit: isCredit),
            const SizedBox(width: 12),

            // ── Info principale ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(otherParty, isCredit),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Montant + date ───────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountDisplay(
                  amount: amount,
                  isPositive: isCredit,
                  showSign: true,
                  fontSize: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFormat.format(transaction.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(String otherParty, bool isCredit) {
    switch (transaction.type) {
      case TransactionType.transfer:
        return isCredit ? 'De @$otherParty' : 'À @$otherParty';
      case TransactionType.purchase:
        return 'Achat marketplace';
      case TransactionType.auction:
        return isCredit ? 'Gain enchère' : 'Paiement enchère';
      case TransactionType.loan:
        return isCredit ? 'Prêt reçu' : 'Remboursement';
      case TransactionType.reward:
        return 'Récompense';
      case TransactionType.tax:
        return 'Taxe';
      case TransactionType.adminCredit:
        return 'Crédit admin';
      case TransactionType.adminDebit:
        return 'Débit admin';
      case TransactionType.initialBalance:
        return 'Solde initial';
    }
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, required this.isCredit});
  final TransactionType type;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final (icon, bg) = _iconData();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: bg, size: 20),
    );
  }

  (IconData, Color) _iconData() {
    switch (type) {
      case TransactionType.transfer:
        return isCredit
            ? (Icons.arrow_downward_rounded, AppTheme.positive)
            : (Icons.arrow_upward_rounded, AppTheme.negative);
      case TransactionType.purchase:
        return (Icons.storefront_rounded, AppTheme.gold);
      case TransactionType.auction:
        return (Icons.gavel_rounded, const Color(0xFF6C5CE7));
      case TransactionType.loan:
        return (Icons.handshake_rounded, const Color(0xFF0984E3));
      case TransactionType.reward:
        return (Icons.star_rounded, AppTheme.gold);
      case TransactionType.tax:
        return (Icons.percent_rounded, AppTheme.negative);
      case TransactionType.adminCredit:
        return (Icons.add_circle_rounded, AppTheme.positive);
      case TransactionType.adminDebit:
        return (Icons.remove_circle_rounded, AppTheme.negative);
      case TransactionType.initialBalance:
        return (Icons.account_balance_rounded, AppTheme.gold);
    }
  }
}
