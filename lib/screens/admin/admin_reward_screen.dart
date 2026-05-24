import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';

class AdminRewardScreen extends ConsumerStatefulWidget {
  const AdminRewardScreen({super.key});

  @override
  ConsumerState<AdminRewardScreen> createState() => _AdminRewardScreenState();
}

class _AdminRewardScreenState extends ConsumerState<AdminRewardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).rewardAll(
            amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
            reason: _reasonCtrl.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Récompense distribuée'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Distribuer une récompense')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribution globale',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cette action crédite tous les comptes actifs avec le même montant.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Montant par personne',
                            suffixText: 'SC',
                          ),
                          validator: (value) {
                            final amount =
                                double.tryParse(value?.replaceAll(',', '.') ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Entrez un montant valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Raison',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: state.isLoading ? null : _submit,
            icon: const Icon(Icons.card_giftcard_rounded),
            label: const Text('Distribuer'),
          ),
        ),
      ),
    );
  }
}
