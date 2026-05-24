import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
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
  final _durationHoursCtrl = TextEditingController(
    text: '${AppConstants.auctionDefaultDurationHours}',
  );
  final _durationMinutesCtrl = TextEditingController(text: '0');
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    _durationHoursCtrl.dispose();
    _durationMinutesCtrl.dispose();
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
      final path = 'marketplace/auctions/$timestamp.jpg';
      _imageCtrl.text = await _uploadImage(bytes, path);
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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

    final startsAt = DateTime.now();
    final durationHours = int.parse(_durationHoursCtrl.text.trim());
    final durationMinutes = int.parse(_durationMinutesCtrl.text.trim());
    final totalMinutes = (durationHours * 60) + durationMinutes;

    try {
      await ref.read(adminActionsProvider.notifier).createAuction(
            itemName: _nameCtrl.text.trim(),
            itemDescription: _descCtrl.text.trim(),
            startingPrice: double.parse(_priceCtrl.text.replaceAll(',', '.')),
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(minutes: totalMinutes)),
            imageUrl:
                _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enchère créée'),
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

  String? _validateDuration() {
    final hours = int.tryParse(_durationHoursCtrl.text.trim());
    final minutes = int.tryParse(_durationMinutesCtrl.text.trim());

    if (hours == null || hours < 0) {
      return 'Heures invalides';
    }
    if (minutes == null || minutes < 0 || minutes > 59) {
      return 'Minutes invalides';
    }
    if ((hours * 60) + minutes <= 0) {
      return 'Entrez une durée valide';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading || _isUploadingImage,
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
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’objet',
                      ),
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
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Durée',
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
                          return 'Entrez un prix valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationHoursCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Heures',
                            ),
                            validator: (_) => _validateDuration(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationMinutesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                            ),
                            validator: (_) => _validateDuration(),
                          ),
                        ),
                      ],
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
