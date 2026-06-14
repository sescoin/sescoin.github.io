import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      maxDailySc: _parseDouble(_dailyCtrl, fallback: 5000),
      maxWeeklySc: _parseDouble(_weeklyCtrl, fallback: 1000),
      maxActiveLoans: _parseInt(_activeLoansCtrl, fallback: 3),
      maxDurationDays: _parseInt(_durationCtrl, fallback: 14),
      maxInterestRate: _parseDouble(_interestCtrl, fallback: 100),
      minBalanceSc: _parseDouble(_minBalanceCtrl, fallback: 10),
    );
    try {
      await ref.read(adminActionsProvider.notifier).updateLoanConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètres enregistrés'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
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
                      final filtered = _filter(loans);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Aucun prêt enregistré'
                                : 'Aucun prêt pour "$_searchQuery"',
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
                      hint: '5000',
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

// ── Tile prêt (lecture seule, vue admin) ──────────────────────────────────────

class _AdminLoanTile extends StatelessWidget {
  const _AdminLoanTile({required this.loan, required this.dateFmt});

  final Loan loan;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (loan.status) {
      LoanStatus.pending => ('En attente', AppTheme.warning),
      LoanStatus.active => ('Actif', AppTheme.positive),
      LoanStatus.repaid => ('Remboursé', Colors.grey),
      LoanStatus.defaulted => ('En retard', AppTheme.negative),
      LoanStatus.rejected => ('Refusé', AppTheme.negative),
      LoanStatus.cancelled => ('Annulé', Colors.grey),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(label: statusLabel, color: statusColor),
                if (loan.isOverdue) ...[
                  const SizedBox(width: 6),
                  _StatusChip(label: 'En retard', color: AppTheme.negative),
                ],
                const Spacer(),
                Text(
                  '${loan.principal.toStringAsFixed(2)} SC',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '−',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.negative,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${loan.borrowerUsername}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '·',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.positive,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${loan.lenderUsername}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (loan.dueDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 12,
                    color: loan.isOverdue
                        ? AppTheme.negative
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Échéance : ${dateFmt.format(loan.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: loan.isOverdue
                          ? AppTheme.negative
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (loan.interestRate > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${loan.interestRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (loan.isActive || loan.status == LoanStatus.repaid) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: loan.repaymentProgress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: AppTheme.positive,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Remboursé : ${loan.amountRepaid.toStringAsFixed(2)} / ${loan.totalDue.toStringAsFixed(2)} SC',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.gold,
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
