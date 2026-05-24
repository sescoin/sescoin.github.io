import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/marketplace_item.dart';
import '../../providers/admin_provider.dart';

class AdminMarketItemFormScreen extends ConsumerStatefulWidget {
  const AdminMarketItemFormScreen({
    super.key,
    this.initialItem,
  });

  final MarketplaceItem? initialItem;

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
  final _maxPerUserCtrl = TextEditingController(text: '-1');
  final _imageCtrl = TextEditingController();
  bool _isUploadingImage = false;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _nameCtrl.text = item.name;
      _descCtrl.text = item.description;
      _priceCtrl.text = item.price.toStringAsFixed(2);
      _categoryCtrl.text = item.category;
      _stockCtrl.text = '${item.stock}';
      _maxPerUserCtrl.text = '${item.maxPerUser}';
      _imageCtrl.text = item.imageUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _stockCtrl.dispose();
    _maxPerUserCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<String> _uploadImage(Uint8List bytes, String path) async {
    final storage = Supabase.instance.client.storage;
    final buckets = [
      AppConstants.bucketMarketplace,
      AppConstants.bucketAvatars,
    ];

    Object? lastError;
    for (final bucket in buckets) {
      try {
        await storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        return storage.from(bucket).getPublicUrl(path);
      } catch (error) {
        lastError = error;
        final message = error.toString().toLowerCase();
        final isMissingBucket = message.contains('bucket not found') ||
            message.contains('statuscode: 404');
        if (!isMissingBucket || bucket == buckets.last) {
          rethrow;
        }
      }
    }

    throw lastError ?? Exception('Impossible d’envoyer l’image.');
  }

  Future<void> _pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'marketplace/items/$timestamp.jpg';
      _imageCtrl.text = await _uploadImage(bytes, path);
      setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      if (_isEditing) {
        await ref.read(adminActionsProvider.notifier).updateItem(
              itemId: widget.initialItem!.id,
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              price: double.parse(_priceCtrl.text.replaceAll(',', '.')),
              category: _categoryCtrl.text.trim(),
              stock: int.parse(_stockCtrl.text.trim()),
              maxPerUser: int.parse(_maxPerUserCtrl.text.trim()),
              imageUrl:
                  _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
            );
      } else {
        await ref.read(adminActionsProvider.notifier).createItem(
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              price: double.parse(_priceCtrl.text.replaceAll(',', '.')),
              category: _categoryCtrl.text.trim(),
              stock: int.parse(_stockCtrl.text.trim()),
              maxPerUser: int.parse(_maxPerUserCtrl.text.trim()),
              imageUrl:
                  _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
            );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Offre boutique mise à jour'
                : 'Offre boutique créée',
          ),
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

  String? _validateIntegerField(
    String? value, {
    required String invalidMessage,
    bool allowUnlimited = false,
  }) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return invalidMessage;
    }
    if (allowUnlimited && parsed == -1) {
      return null;
    }
    if (parsed <= 0) {
      return invalidMessage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading || _isUploadingImage,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? 'Modifier une offre boutique'
                : 'Nouvelle offre boutique',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Informations',
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Entrez un nom';
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
                          return 'Entrez une catégorie';
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
                          return 'Entrez un prix valide';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Contenu',
                  children: [
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
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock'),
                      validator: (value) => _validateIntegerField(
                        value,
                        invalidMessage: 'Entrez un stock valide',
                        allowUnlimited: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _maxPerUserCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Limite par personne',
                      ),
                      validator: (value) => _validateIntegerField(
                        value,
                        invalidMessage: 'Entrez une limite valide',
                        allowUnlimited: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL image',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choisir depuis la galerie'),
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
            onPressed: state.isLoading || _isUploadingImage ? null : _submit,
            icon: Icon(
              _isEditing ? Icons.save_rounded : Icons.add_business_rounded,
            ),
            label: Text(
              _isEditing ? 'Enregistrer l’offre' : 'Créer l’offre',
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
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
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
