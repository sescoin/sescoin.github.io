import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';

class AdminMarketItemFormScreen extends ConsumerStatefulWidget {
  const AdminMarketItemFormScreen({super.key});

  @override
  ConsumerState<AdminMarketItemFormScreen> createState() =>
      _AdminMarketItemFormScreenState();
}

class _AdminMarketItemFormScreenState
    extends ConsumerState<AdminMarketItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'Divers');
  final _stockCtrl = TextEditingController(text: '-1');
  final _imageCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(adminActionsProvider.notifier).createItem(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            price: double.parse(_priceCtrl.text.replaceAll(',', '.')),
            category: _categoryCtrl.text.trim(),
            stock: int.parse(_stockCtrl.text.trim()),
            imageUrl:
                _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offre boutique créée.'),
          backgroundColor: AppTheme.positive,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nouvelle offre boutique')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Informations',
                  subtitle:
                      'Crée une vraie fiche boutique avec un titre, une catégorie et un prix.',
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Entre un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Entre une catégorie';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix',
                        suffixText: 'SC',
                      ),
                      validator: (value) {
                        final amount =
                            double.tryParse(value?.replaceAll(',', '.') ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Entre un prix valide';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Contenu',
                  subtitle:
                      'Garde une carte compacte côté élève avec une description courte et lisible.',
                  children: [
                    TextFormField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Entre une description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        helperText: '-1 = illimité',
                      ),
                      validator: (value) {
                        final stock = int.tryParse(value?.trim() ?? '');
                        if (stock == null || stock == 0 || stock < -1) {
                          return 'Entre un stock valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL image',
                        hintText: 'Optionnelle',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: state.isLoading ? null : _submit,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Créer l’offre'),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
