import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/admin_widgets.dart';
import '../../common/animations.dart';
import '../../common/app_feedback.dart';
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
      AppFeedback.success(context, 'Récompense distribuée ! 🎉');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppFeedback.error(context, error);
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const FadeSlideIn(
                  child: AdminActionHeader(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Distribution globale',
                    message:
                        'Cette action crédite tous les comptes actifs avec le '
                        'même montant, en une seule fois.',
                    color: AppTheme.positive,
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn.staggered(
                  index: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Montant par personne',
                              prefixIcon: Icon(Icons.savings_rounded),
                              suffixText: 'SC',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                value?.replaceAll(',', '.') ?? '',
                              );
                              if (amount == null || amount <= 0) {
                                return 'Entrez un montant valide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Raison affichée aux utilisateurs',
                              hintText: 'Ex : Bravo pour le projet !',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ],
                      ),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.positive,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}
