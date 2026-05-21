import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../models/currency_rate.dart';
import '../../providers/admin_provider.dart';
import '../../providers/currency_provider.dart';

class AdminRateScreen extends ConsumerStatefulWidget {
  const AdminRateScreen({super.key});

  @override
  ConsumerState<AdminRateScreen> createState() => _AdminRateScreenState();
}

class _AdminRateScreenState extends ConsumerState<AdminRateScreen> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _reasonCtrl;
  late final List<TextEditingController> _demandCtrls;
  late final List<TextEditingController> _supplyCtrls;
  late final List<TextEditingController> _priceCtrls;

  @override
  void initState() {
    super.initState();
    final current = ref.read(currentRateProvider).valueOrNull ??
        CurrencyRate(
          id: 'default',
          rate: 1.0,
          changePercent: 0,
          isManual: false,
          createdAt: DateTime.now(),
          demandPoints: CurrencyRate.defaultDemandPoints,
          supplyPoints: CurrencyRate.defaultSupplyPoints,
          pricePoints: CurrencyRate.defaultPricePoints,
        );
    _rateCtrl = TextEditingController(text: current.rate.toStringAsFixed(4));
    _reasonCtrl = TextEditingController(text: current.reason ?? '');
    _demandCtrls = current.demandPoints
        .map((value) => TextEditingController(text: value.toStringAsFixed(0)))
        .toList();
    _supplyCtrls = current.supplyPoints
        .map((value) => TextEditingController(text: value.toStringAsFixed(0)))
        .toList();
    _priceCtrls = current.pricePoints
        .map((value) => TextEditingController(text: value.toStringAsFixed(2)))
        .toList();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _reasonCtrl.dispose();
    for (final ctrl in _demandCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _supplyCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _priceCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  double _parseValue(TextEditingController ctrl, {double fallback = 0}) {
    return double.tryParse(ctrl.text.replaceAll(',', '.')) ?? fallback;
  }

  void _clearPoints() {
    setState(() {
      for (final ctrl in _demandCtrls) {
        ctrl.text = '0';
      }
      for (final ctrl in _supplyCtrls) {
        ctrl.text = '0';
      }
      for (final ctrl in _priceCtrls) {
        ctrl.text = '0.00';
      }
    });
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateCtrl.text.replaceAll(',', '.')) ?? 0;
    if (rate <= 0) return;

    final demandPoints =
        _demandCtrls.map((ctrl) => _parseValue(ctrl)).toList(growable: false);
    final supplyPoints =
        _supplyCtrls.map((ctrl) => _parseValue(ctrl)).toList(growable: false);
    final pricePoints =
        _priceCtrls.map((ctrl) => _parseValue(ctrl)).toList(growable: false);

    try {
      await ref.read(adminActionsProvider.notifier).setManualRate(
            rate: rate,
            reason: _reasonCtrl.text.trim().isEmpty
                ? 'Modification manuelle du cours'
                : _reasonCtrl.text.trim(),
            demandPoints: demandPoints,
            supplyPoints: supplyPoints,
            pricePoints: pricePoints,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cours fixé à ${rate.toStringAsFixed(4)}'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentRateProvider).valueOrNull;
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      message: 'Traitement...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Modifier le cours')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Cours actuel : ${(current?.rate ?? 1).toStringAsFixed(4)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.gold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vous pouvez modifier librement les 10 points du graphique.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Vider les points'),
                  onPressed: _clearPoints,
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.25)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cours affiché en haut',
                hintText: 'Ex: 8.0000 ou 40.0000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison',
                hintText: 'Ex: Décision de la prof / évolution offre-demande',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demande',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offre',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prix (EUR)',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(CurrencyRate.chartPointCount, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${index + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _demandCtrls[index],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _supplyCtrls[index],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _priceCtrls[index],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0.00',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }
}
