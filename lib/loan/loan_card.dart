import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/text_sanitizer.dart';
import '../../core/theme.dart';
import '../../models/loan.dart';
import '../common/user_avatar.dart';

class LoanCard extends StatelessWidget {
  const LoanCard({
    super.key,
    required this.loan,
    required this.currentUserId,
    this.onAccept,
    this.onReject,
    this.onRepay,
    this.onCancel,
    this.onDelete,
    this.isLoading = false,
  });

  final Loan loan;
  final String currentUserId;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onRepay;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final bool isLoading;

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  bool get _isBorrower => loan.borrowerId == currentUserId;
  bool get _isLender => loan.lenderId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LoanStatusBadge(status: loan.status),
                const Spacer(),
                if (loan.isOverdue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.negative.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'En retard',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.negative,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isLoading ? null : onDelete,
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.negative,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                UserAvatar(
                  username:
                      _isLender ? loan.borrowerUsername : loan.lenderUsername,
                  avatarUrl:
                      _isLender ? loan.borrowerAvatarUrl : loan.lenderAvatarUrl,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLender ? 'Vous prêtez à' : 'Prêteur',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _isLender
                            ? '@${loan.borrowerUsername}'
                            : '@${loan.lenderUsername}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AmountInfo(label: 'Principal', amount: loan.principal),
                _AmountInfo(
                  label: 'Intérêts (${loan.interestRate.toStringAsFixed(1)}%)',
                  amount: loan.interestAmount,
                ),
                _AmountInfo(
                  label: 'Total dû',
                  amount: loan.totalDue,
                  bold: true,
                ),
              ],
            ),
            if (loan.isActive || loan.status == LoanStatus.repaid) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remboursé : ${loan.amountRepaid.toStringAsFixed(2)} SC',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Restant : ${loan.remainingAmount.toStringAsFixed(2)} SC',
                    style: TextStyle(
                      fontSize: 12,
                      color: loan.remainingAmount > 0
                          ? AppTheme.negative
                          : AppTheme.positive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loan.repaymentProgress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: AppTheme.positive,
                  minHeight: 6,
                ),
              ),
            ],
            if (loan.dueDate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: loan.isOverdue
                        ? AppTheme.negative
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Échéance : ${_dateFormat.format(loan.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: loan.isOverdue
                          ? AppTheme.negative
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (loan.note != null && loan.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${TextSanitizer.clean(loan.note!.trim())}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_isLender && loan.isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.negative,
                side: const BorderSide(color: AppTheme.negative),
              ),
              child: const Text('Refuser'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onAccept,
              child: const Text('Accepter'),
            ),
          ),
        ],
      );
    }

    if (_isBorrower && loan.isPending) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoading ? null : onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.negative,
            side: const BorderSide(color: AppTheme.negative),
          ),
          child: const Text('Annuler la demande'),
        ),
      );
    }

    if (_isBorrower && loan.isActive && !loan.isFullyRepaid) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onRepay,
          icon: const Icon(Icons.payment_rounded, size: 18),
          label: const Text('Rembourser'),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LoanStatusBadge extends StatelessWidget {
  const _LoanStatusBadge({required this.status});

  final LoanStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LoanStatus.pending => ('En attente', AppTheme.warning),
      LoanStatus.active => ('Actif', AppTheme.positive),
      LoanStatus.repaid => ('Remboursé', Colors.grey),
      LoanStatus.defaulted => ('En défaut', AppTheme.negative),
      LoanStatus.rejected => ('Refusé', AppTheme.negative),
      LoanStatus.cancelled => ('Annulé', Colors.grey),
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

class _AmountInfo extends StatelessWidget {
  const _AmountInfo({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} SC',
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? AppTheme.gold : null,
          ),
        ),
      ],
    );
  }
}
