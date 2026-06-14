import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/loan_config.dart';
import '../../providers/admin_provider.dart';
import '../../providers/loan_provider.dart';

class AdminLoansScreen extends ConsumerStatefulWidget {
  const AdminLoansScreen({super.key});

  @override
  ConsumerState<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

class _AdminLoansScreenState extends ConsumerState<AdminLoansScreen> {
  late final TextEditingController _dailyCtrl;
  late final TextEditingController _weeklyCtrl;
  late final TextEditingController _activeLoansCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _interestCtrl;
  late final TextEditingController _minBalanceCtrl;

  @override
  void initState() {
    super.initState();
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
    _dailyCtrl.dispose();
    _weeklyCtrl.dispose();
    _activeLoansCtrl.dispose();
    _durationCtrl.dispose();
    _interestCtrl.dispose();
    _minBalanceCtrl.dispose();
    super.dispose();
  }

  double _parseDouble(TextEditingController ctrl, {double fallback = 0}) =>
      double.tryParse(ctrl.text.replaceAll(',', '.')) ?? fallback;

  int _parseInt(TextEditingController ctrl, {int fallback = 1}) =>
      int.tryParse(ctrl.text.trim()) ?? fallback;

  Future<void> _save() async {
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
      Navigator.of(context).pop();
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
    final configAsync = ref.watch(loanConfigProvider);
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Paramètres des prêts')),
        body: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Erreur de chargement')),
          data: (_) => ListView(
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
                    suffix: '%',
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
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
