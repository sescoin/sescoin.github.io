import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/admin_widgets.dart';
import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';

class AdminTaxScreen extends ConsumerStatefulWidget {
  const AdminTaxScreen({super.key});

  @override
  ConsumerState<AdminTaxScreen> createState() => _AdminTaxScreenState();
}

class _AdminTaxScreenState extends ConsumerState<AdminTaxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _percentCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _percentCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final percent = double.parse(_percentCtrl.text.replaceAll(',', '.'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Confirmer la taxe'),
        content: Text(
          'Appliquer une taxe de $percent% sur tous les comptes ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
            ),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(adminActionsProvider.notifier).taxAll(
              percent: percent,
              reason: _reasonCtrl.text,
            );
        if (mounted) {
          AppFeedback.success(context, 'Taxe de $percent% appliquée !');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          AppFeedback.error(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Taxe globale')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const FadeSlideIn(
                  child: AdminActionHeader(
                    icon: Icons.percent_rounded,
                    title: 'Prélèvement global',
                    message:
                        'Cette action prélève un pourcentage sur tous les '
                        'comptes actifs. Elle est irréversible.',
                    color: AppTheme.negative,
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
                            controller: _percentCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Pourcentage de taxe',
                              hintText: 'Ex : 5',
                              prefixIcon: Icon(Icons.percent_rounded),
                              suffixText: '%',
                            ),
                            validator: (v) {
                              final n =
                                  double.tryParse(v?.replaceAll(',', '.') ?? '');
                              if (n == null || n <= 0 || n > 100) {
                                return 'Entre 0% et 100%';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Raison affichée aux utilisateurs',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Raison requise' : null,
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
            icon: const Icon(Icons.percent_rounded),
            label: const Text('Appliquer la taxe'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.negative,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}
