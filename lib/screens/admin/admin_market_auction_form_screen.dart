import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';

class AdminMarketAuctionFormScreen extends ConsumerStatefulWidget {
  const AdminMarketAuctionFormScreen({super.key});

  @override
  ConsumerState<AdminMarketAuctionFormScreen> createState() =>
      _AdminMarketAuctionFormScreenState();
}

class _AdminMarketAuctionFormScreenState
    extends ConsumerState<AdminMarketAuctionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '24');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startsAt = DateTime.now();
    final durationHours = int.parse(_durationCtrl.text.trim());

    try {
      await ref.read(adminActionsProvider.notifier).createAuction(
            itemName: _nameCtrl.text.trim(),
            itemDescription: _descCtrl.text.trim(),
            startingPrice: double.parse(_priceCtrl.text.replaceAll(',', '.')),
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(hours: durationHours)),
            imageUrl:
                _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enchère créée.'),
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
        appBar: AppBar(title: const Text('Nouvelle enchère')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Objet',
                  subtitle:
                      'Prépare une enchère claire avec un nom, un visuel et un texte de contexte.',
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’objet',
                      ),
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
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
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
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Règles',
                  subtitle:
                      'Définis le prix de départ et la durée avant publication.',
                  children: [
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix de départ',
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée',
                        suffixText: 'heures',
                      ),
                      validator: (value) {
                        final hours = int.tryParse(value?.trim() ?? '');
                        if (hours == null || hours <= 0) {
                          return 'Entre une durée valide';
                        }
                        return null;
                      },
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
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('Créer l’enchère'),
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
