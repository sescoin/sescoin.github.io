import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/app_feedback.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/loan.dart';
import '../../models/loan_config.dart';
import '../../providers/admin_provider.dart';
import '../../providers/loan_provider.dart';

class AdminLoansScreen extends ConsumerStatefulWidget {
  const AdminLoansScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

class _AdminLoansScreenState extends ConsumerState<AdminLoansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Onglet liste
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Onglet paramètres
  late final TextEditingController _dailyCtrl;
  late final TextEditingController _weeklyCtrl;
  late final TextEditingController _activeLoansCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _interestCtrl;
  late final TextEditingController _minBalanceCtrl;

  static final _dateFmt = DateFormat('dd/MM/yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    final cfg = ref.read(loanConfigProvider).valueOrNull ?? LoanConfig.defaults;
    _dailyCtrl = TextEditingController(text: cfg.maxDailySc.toStringAsFixed(0));
    _weeklyCtrl = TextEditingController(text: cfg.maxWeeklySc.toStringAsFixed(0));
    _activeLoansCtrl = TextEditingController(text: cfg.maxActiveLoans.toString());
    _durationCtrl = TextEditingController(text: cfg.maxDurationDays.toString());
    _interestCtrl = TextEditingController(text: cfg.maxInterestRate.toStringAsFixed(0));
    _minBalanceCtrl = TextEditingController(text: cfg.minBalanceSc.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _dailyCtrl.dispose();
    _weeklyCtrl.dispose();
    _activeLoansCtrl.dispose();
    _durationCtrl.dispose();
    _interestCtrl.dispose();
    _minBalanceCtrl.dispose();
    super.dispose();
  }

  List<Loan> _filter(List<Loan> loans) {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return loans;
    return loans.where((l) {
      return l.borrowerUsername.toLowerCase().contains(q) ||
          l.lenderUsername.toLowerCase().contains(q);
    }).toList();
  }

  double _parseDouble(TextEditingController c, {double fallback = 0}) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? fallback;

  int _parseInt(TextEditingController c, {int fallback = 1}) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _saveConfig() async {
    final config = LoanConfig(
      maxDailySc: _parseDouble(_dailyCtrl, fallback: 100),
      maxWeeklySc: _parseDouble(_weeklyCtrl, fallback: 1000),
      maxActiveLoans: _parseInt(_activeLoansCtrl, fallback: 3),
      maxDurationDays: _parseInt(_durationCtrl, fallback: 14),
      maxInterestRate: _parseDouble(_interestCtrl, fallback: 100),
      minBalanceSc: _parseDouble(_minBalanceCtrl, fallback: 10),
    );
    try {
      await ref.read(adminActionsProvider.notifier).updateLoanConfig(config);
      if (!mounted) return;
      AppFeedback.success(context, 'Paramètres enregistrés.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(allLoansAdminProvider);
    final adminState = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: adminState.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prêts'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Prêts'),
              Tab(text: 'Paramètres'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Onglet liste ──────────────────────────────────────────────────
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un utilisateur…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: loansAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur : $e')),
                    data: (loans) {
                      // Vue admin : seuls les prêts en cours. Sont écartés les
                      // prêts remboursés, refusés, annulés, en attente
                      // d'acceptation — et ceux en retard.
                      final filtered = _filter(loans)
                          .where((l) => l.status == LoanStatus.active)
                          .toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Aucun prêt en cours'
                                : 'Aucun prêt en cours pour "$_searchQuery"',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(allLoansAdminProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _AdminLoanTile(loan: filtered[i], dateFmt: _dateFmt),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Onglet paramètres ─────────────────────────────────────────────
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  title: 'Limites d\'emprunt',
                  children: [
                    _Field(
                      controller: _dailyCtrl,
                      label: 'Limite quotidienne',
                      suffix: 'SC / jour',
                      hint: '100',
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _weeklyCtrl,
                      label: 'Limite hebdomadaire',
                      suffix: 'SC / semaine',
                      hint: '1000',
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _activeLoansCtrl,
                      label: 'Prêts actifs simultanés max',
                      suffix: 'prêts',
                      hint: '3',
                      isInt: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Conditions',
                  children: [
                    _Field(
                      controller: _durationCtrl,
                      label: 'Durée maximale',
                      suffix: 'jours',
                      hint: '14',
                      isInt: true,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _interestCtrl,
                      label: 'Taux d\'intérêt maximum',
                      suffix: 'pourcent',
                      hint: '100',
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _minBalanceCtrl,
                      label: 'Solde minimum pour emprunter',
                      suffix: 'SC',
                      hint: '10',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile prêt (vue admin) ─────────────────────────────────────────────────────

(String, Color) _statusOf(Loan loan) => switch (loan.status) {
      LoanStatus.pending => ('En attente', AppTheme.warning),
      LoanStatus.active => ('Actif', AppTheme.positive),
      LoanStatus.repaid => ('Remboursé', Colors.grey),
      LoanStatus.defaulted => ('En retard', AppTheme.negative),
      LoanStatus.rejected => ('Refusé', AppTheme.negative),
      LoanStatus.cancelled => ('Annulé', Colors.grey),
    };

/// Ligne de liste volontairement sobre : statut, montant et les deux parties.
/// Tout le reste est renvoyé au panneau de détail, ouvert au clic.
class _AdminLoanTile extends StatelessWidget {
  const _AdminLoanTile({required this.loan, required this.dateFmt});

  final Loan loan;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusOf(loan);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showLoanDetail(context, loan, dateFmt),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusChip(label: statusLabel, color: statusColor),
                        const SizedBox(width: 9),
                        Text(
                          '${loan.principal.toStringAsFixed(2)} SC',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: context.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PartyLine(
                      label: 'Prêteur',
                      username: loan.lenderUsername,
                      color: AppTheme.positive,
                    ),
                    const SizedBox(height: 4),
                    _PartyLine(
                      label: 'Emprunteur',
                      username: loan.borrowerUsername,
                      color: AppTheme.negative,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyLine extends StatelessWidget {
  const _PartyLine({
    required this.label,
    required this.username,
    required this.color,
  });

  final String label;
  final String username;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ── Détail d'un prêt ──────────────────────────────────────────────────────────

void _showLoanDetail(BuildContext context, Loan loan, DateFormat dateFmt) {
  final (statusLabel, statusColor) = _statusOf(loan);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final accent = ctx.accent;
      final note = loan.note?.trim();

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Montant en vedette
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      accent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${loan.principal.toStringAsFixed(2)} SC',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(label: statusLabel, color: statusColor),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DetailRow(
                icon: Icons.arrow_upward_rounded,
                label: 'Prêteur',
                value: '@${loan.lenderUsername}',
                color: AppTheme.positive,
              ),
              _DetailRow(
                icon: Icons.arrow_downward_rounded,
                label: 'Emprunteur',
                value: '@${loan.borrowerUsername}',
                color: AppTheme.negative,
              ),
              const Divider(height: 28),
              _DetailRow(
                icon: Icons.percent_rounded,
                label: 'Taux d\'intérêt',
                value: '${loan.interestRate.toStringAsFixed(1)} %',
              ),
              _DetailRow(
                icon: Icons.savings_rounded,
                label: 'Intérêts',
                value: '${loan.interestAmount.toStringAsFixed(2)} SC',
              ),
              _DetailRow(
                icon: Icons.summarize_rounded,
                label: 'Total dû',
                value: '${loan.totalDue.toStringAsFixed(2)} SC',
              ),
              _DetailRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Déjà remboursé',
                value: '${loan.amountRepaid.toStringAsFixed(2)} SC',
              ),
              _DetailRow(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Restant dû',
                value: '${loan.remainingAmount.toStringAsFixed(2)} SC',
                color: loan.remainingAmount > 0 ? AppTheme.warning : null,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loan.repaymentProgress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: AppTheme.positive,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(loan.repaymentProgress * 100).toStringAsFixed(0)} % remboursé',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 28),
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Créé le',
                value: dateFmt.format(loan.createdAt),
              ),
              if (loan.dueDate != null)
                _DetailRow(
                  icon: Icons.event_rounded,
                  label: 'Échéance',
                  value: dateFmt.format(loan.dueDate!),
                  color: loan.isOverdue ? AppTheme.negative : null,
                ),
              if (note != null && note.isNotEmpty) ...[
                const Divider(height: 28),
                Text(
                  'Motif',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(note, style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Widgets partagés (paramètres) ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: context.accent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.hint,
    this.isInt = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String hint;
  final bool isInt;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
      ),
    );
  }
}
