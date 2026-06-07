import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/class_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  // Disponibilité du username (null = pas encore vérifié)
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  Timer? _usernameTimer;

  // Initiales calculées depuis prénom + nom
  String get _previewInitials {
    final f = _firstNameCtrl.text.trim();
    final l = _lastNameCtrl.text.trim();
    final fi = f.isNotEmpty ? f[0].toUpperCase() : '';
    final li = l.isNotEmpty ? l[0].toUpperCase() : '';
    return '$fi$li'.isEmpty ? '?' : '$fi$li';
  }

  // Aperçu du username généré
  String get _previewUsername {
    if (_firstNameCtrl.text.isEmpty && _lastNameCtrl.text.isEmpty) return '';
    return AuthService.generateUsername(
      _firstNameCtrl.text,
      _lastNameCtrl.text,
    );
  }

  // Photo personnalisée choisie depuis la galerie
  XFile? _pickedImage;
  Uint8List? _pickedBytes;

  // Classe sélectionnée (optionnel)
  String? _selectedClassId;

  // Valeur sentinelle pour le mode initiales
  static const _initialsKey = '__INITIALS__';

  // Avatar sélectionné (emoji parmi une liste prédéfinie, ou _initialsKey)
  String _selectedAvatar = _initialsKey;
  static const _avatars = [
    '🦁',
    '🐯',
    '🦊',
    '🐺',
    '🦝',
    '🐻',
    '🐼',
    '🐨',
    '🐸',
    '🐙',
    '🦋',
    '🐬',
    '🦄',
    '🐲',
    '🌟',
    '🎯',
    '🔥',
    '⚡',
  ];

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _scheduleUsernameCheck() {
    _usernameTimer?.cancel();
    final username = _previewUsername;
    if (username.isEmpty) {
      setState(() => _usernameAvailable = null);
      return;
    }
    setState(() { _checkingUsername = true; _usernameAvailable = null; });
    _usernameTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        final available = await Supabase.instance.client
            .rpc('is_username_available', params: {'p_username': username});
        if (mounted) {
          setState(() {
            _usernameAvailable = available as bool;
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedBytes = bytes;
        _selectedAvatar = '';
      });
    }
  }

  Future<String> _resolveAvatarUrl() async {
    if (_pickedImage == null) {
      return _selectedAvatar == _initialsKey ? '' : _selectedAvatar;
    }

    final username = AuthService.generateUsername(
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    );
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'requests/${username}_$ts.jpg';

    try {
      final bytes = _pickedBytes ?? await _pickedImage!.readAsBytes();
      await Supabase.instance.client.storage
          .from(AppConstants.bucketAvatars)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return Supabase.instance.client.storage
          .from(AppConstants.bucketAvatars)
          .getPublicUrl(path);
    } catch (_) {
      // Upload impossible (bucket non configuré) → fallback initiales ou emoji
      return _selectedAvatar == _initialsKey || _selectedAvatar.isEmpty
          ? ''
          : _selectedAvatar;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Si des classes existent, une doit être sélectionnée
    final classesValue = ref.read(classListProvider).valueOrNull;
    if (classesValue != null && classesValue.isNotEmpty && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une classe.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // deviceId simplifié (en prod utiliser device_info_plus)
      const deviceId = 'device_placeholder';

      final avatarUrl = await _resolveAvatarUrl();

      await ref.read(currentProfileProvider.notifier).submitAccountRequest(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            password: _passwordCtrl.text,
            avatarUrl: avatarUrl,
            deviceId: deviceId,
            classId: _selectedClassId,
          );
      if (mounted) context.go(AppRoutes.requestSent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Choix avatar / photo ──────────────────────────────────────
              Text(
                'Choisis ton avatar',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // Aperçu + bouton photo
              Row(
                children: [
                  // Aperçu circulaire
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          AppTheme.gold.withValues(alpha: 0.12),
                      backgroundImage: _pickedBytes != null
                          ? MemoryImage(_pickedBytes!)
                          : null,
                      child: _pickedImage == null
                          ? (_selectedAvatar == _initialsKey
                              ? Text(
                                  _previewInitials,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.gold,
                                  ),
                                )
                              : Text(
                                  _selectedAvatar.isEmpty ? '🦁' : _selectedAvatar,
                                  style: const TextStyle(fontSize: 30),
                                ))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _pickedImage != null
                            ? 'Photo choisie ✓'
                            : 'Choisir une photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _pickedImage != null
                            ? AppTheme.positive
                            : AppTheme.gold,
                        side: BorderSide(
                          color: _pickedImage != null
                              ? AppTheme.positive
                              : AppTheme.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ou choisir un emoji
              Text(
                'Ou choisir un emoji / initiales',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  // +1 pour la carte initiales en première position
                  itemCount: _avatars.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    // Première carte = initiales
                    if (i == 0) {
                      final selected =
                          _pickedImage == null && _selectedAvatar == _initialsKey;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedAvatar = _initialsKey;
                          _pickedImage = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppTheme.gold.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.12),
                            border: Border.all(
                              color: selected ? AppTheme.gold : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _previewInitials,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? AppTheme.gold
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final avatar = _avatars[i - 1];
                    final selected =
                        _pickedImage == null && avatar == _selectedAvatar;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedAvatar = avatar;
                        _pickedImage = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.gold.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected ? AppTheme.gold : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            avatar,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // ── Prénom ───────────────────────────────────────────────────
              Text(
                'Prénom',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _scheduleUsernameCheck(),
                decoration: const InputDecoration(hintText: 'Prénom'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Prénom requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Nom ──────────────────────────────────────────────────────
              Text(
                'Nom',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _scheduleUsernameCheck(),
                decoration: const InputDecoration(hintText: 'Nom'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nom requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // ── Aperçu username + disponibilité ─────────────────────────
              if (_previewUsername.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _usernameAvailable == false
                        ? AppTheme.negative.withValues(alpha: 0.08)
                        : AppTheme.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alternate_email,
                          size: 14,
                          color: _usernameAvailable == false
                              ? AppTheme.negative
                              : AppTheme.gold),
                      const SizedBox(width: 6),
                      Text(
                        'Identifiant : $_previewUsername',
                        style: TextStyle(
                          color: _usernameAvailable == false
                              ? AppTheme.negative
                              : AppTheme.gold,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_checkingUsername)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else if (_usernameAvailable == true)
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: AppTheme.positive)
                      else if (_usernameAvailable == false)
                        const Icon(Icons.cancel_rounded,
                            size: 14, color: AppTheme.negative),
                    ],
                  ),
                ),
                if (_usernameAvailable == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Ce prénom + nom est déjà utilisé ou en attente d\'approbation.\nChoisis un autre prénom ou ajoute une initiale.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.negative.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),

              // ── Mot de passe ─────────────────────────────────────────────
              Text(
                'Mot de passe',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: '8 caractères minimum',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < AppConstants.passwordMinLength) {
                    return 'Minimum ${AppConstants.passwordMinLength} caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Confirmer le mot de passe',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Confirme ton mot de passe',
                ),
                validator: (v) {
                  if (v != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Classe ──────────────────────────────────────────────────
              _ClassSelector(
                selectedClassId: _selectedClassId,
                onChanged: (id) => setState(() => _selectedClassId = id),
              ),
              const SizedBox(height: 32),

              // ── Bouton ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Envoyer la demande'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Déjà un compte ? Se connecter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sélecteur de classe (obligatoire si des classes existent) ─────────────────

class _ClassSelector extends ConsumerWidget {
  const _ClassSelector({
    required this.selectedClassId,
    required this.onChanged,
  });

  final String? selectedClassId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return classesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (classes) {
        if (classes.isEmpty) return const SizedBox.shrink();

        // Auto-sélectionner la première classe si rien n'est sélectionné
        if (selectedClassId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(classes.first.id);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classe',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: classes.map(
                (c) => _ClassChip(
                  label: c.name,
                  selected: selectedClassId == c.id,
                  onTap: () => onChanged(c.id),
                ),
              ).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.gold : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.gold : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
