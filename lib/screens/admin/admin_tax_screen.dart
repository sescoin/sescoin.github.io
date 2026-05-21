import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../common/loading_overlay.dart';

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
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negative),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Taxe de $percent% appliquée !'),
              backgroundColor: AppTheme.positive,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
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
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.negative.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.negative.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: AppTheme.negative),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cette action prélève un pourcentage sur '
                          'TOUS les comptes actifs. Irréversible.',
                          style: TextStyle(
                            color: AppTheme.negative,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Pourcentage de taxe',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _percentCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Ex: 5',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                    if (n == null || n <= 0 || n > 100) {
                      return '0% - 100%';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Raison',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Taxe mensuelle',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Raison requise' : null,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _submit,
                    icon: const Icon(Icons.percent_rounded),
                    label: const Text('Appliquer la taxe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.negative,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
