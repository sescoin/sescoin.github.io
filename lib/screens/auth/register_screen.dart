import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
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
    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });
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

  /// Retire la photo importée pour revenir aux initiales / emoji.
  void _removePhoto() {
    setState(() {
      _pickedImage = null;
      _pickedBytes = null;
      _selectedAvatar = _initialsKey;
    });
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
    if (classesValue != null &&
        classesValue.isNotEmpty &&
        _selectedClassId == null) {
      AppFeedback.warning(
        context,
        'Une classe doit être sélectionnée avant l\'envoi.',
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
        AppFeedback.error(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Carte profil ─────────────────────────────────────────
                  FadeSlideIn.staggered(
                    index: 0,
                    child: _SectionCard(
                      title: 'Profil',
                      icon: Icons.person_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              accent.withValues(alpha: 0.45),
                                          width: 2,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor:
                                            accent.withValues(alpha: 0.12),
                                        backgroundImage: _pickedBytes != null
                                            ? MemoryImage(_pickedBytes!)
                                            : null,
                                        child: _pickedImage == null
                                            ? (_selectedAvatar == _initialsKey
                                                ? Text(
                                                    _previewInitials,
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: accent,
                                                    ),
                                                  )
                                                : Text(
                                                    _selectedAvatar.isEmpty
                                                        ? '🦁'
                                                        : _selectedAvatar,
                                                    style: const TextStyle(
                                                        fontSize: 28),
                                                  ))
                                            : null,
                                      ),
                                    ),
                                  ),
                                  // Croix de suppression (photo importée).
                                  if (_pickedImage != null)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: GestureDetector(
                                        onTap: _removePhoto,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.negative,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: theme.cardColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(
                                      Icons.photo_library_outlined,
                                      size: 18),
                                  label: Text(
                                    _pickedImage != null
                                        ? 'Photo sélectionnée'
                                        : 'Importer une photo',
                                  ),
                                  style: _pickedImage != null
                                      ? OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.positive,
                                          side: const BorderSide(
                                            color: AppTheme.positive,
                                            width: 1.4,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _pickedImage != null
                                ? 'Retirez la photo (croix rouge) pour choisir un emoji ou les initiales.'
                                : 'Ou sélectionner un emoji ou les initiales :',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Bande d'emoji désactivée tant qu'une photo est importée.
                          Opacity(
                            opacity: _pickedImage != null ? 0.4 : 1,
                            child: IgnorePointer(
                              ignoring: _pickedImage != null,
                              child: SizedBox(
                                height: 56,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  // +1 pour la carte initiales en première position
                                  itemCount: _avatars.length + 1,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      final selected = _pickedImage == null &&
                                          _selectedAvatar == _initialsKey;
                                      return _AvatarOption(
                                        selected: selected,
                                        onTap: () => setState(() {
                                          _selectedAvatar = _initialsKey;
                                        }),
                                        child: Text(
                                          _previewInitials,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? accent
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    }

                                    final avatar = _avatars[i - 1];
                                    final selected = _pickedImage == null &&
                                        avatar == _selectedAvatar;
                                    return _AvatarOption(
                                      selected: selected,
                                      onTap: () => setState(() {
                                        _selectedAvatar = avatar;
                                      }),
                                      child: Text(
                                        avatar,
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _firstNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _scheduleUsernameCheck(),
                            decoration: const InputDecoration(
                              labelText: 'Prénom',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Prénom requis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _lastNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _scheduleUsernameCheck(),
                            decoration: const InputDecoration(
                              labelText: 'Nom',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Nom requis';
                              }
                              return null;
                            },
                          ),
                          // ── Aperçu identifiant + disponibilité ───────────
                          if (_previewUsername.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _usernameAvailable == false
                                    ? AppTheme.negative.withValues(alpha: 0.08)
                                    : accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alternate_email,
                                    size: 14,
                                    color: _usernameAvailable == false
                                        ? AppTheme.negative
                                        : accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Identifiant : $_previewUsername',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _usernameAvailable == false
                                            ? AppTheme.negative
                                            : accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_checkingUsername)
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5),
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
                                padding:
                                    const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  'Cet identifiant est déjà utilisé ou en attente '
                                  'd\'approbation.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.negative
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Carte sécurité ───────────────────────────────────────
                  FadeSlideIn.staggered(
                    index: 1,
                    child: _SectionCard(
                      title: 'Sécurité',
                      icon: Icons.lock_rounded,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              hintText: '8 caractères minimum',
                              prefixIcon: const Icon(Icons.key_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null ||
                                  v.length < AppConstants.passwordMinLength) {
                                return 'Minimum ${AppConstants.passwordMinLength} caractères';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              prefixIcon:
                                  Icon(Icons.check_circle_outline_rounded),
                            ),
                            validator: (v) {
                              if (v != _passwordCtrl.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Carte classe ─────────────────────────────────────────
                  _ClassSelector(
                    selectedClassId: _selectedClassId,
                    onChanged: (id) => setState(() => _selectedClassId = id),
                  ),
                  const SizedBox(height: 24),

                  // ── Bouton ───────────────────────────────────────────────
                  FadeSlideIn.staggered(
                    index: 3,
                    child: PressableScale(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              Color.lerp(accent, Colors.black, 0.22)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: _isLoading ? 0.15 : 0.35,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.onAccent,
                                  ),
                                )
                              : Text(
                                  'Envoyer la demande',
                                  style: TextStyle(
                                    color: context.onAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text.rich(
                        TextSpan(
                          text: 'Déjà un compte ?  ',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: 'Se connecter',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }
}

// ── Carte de section ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Option d'avatar (emoji ou initiales) ──────────────────────────────────────

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration(const Duration(milliseconds: 200)),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Center(child: child),
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

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: FadeSlideIn.staggered(
            index: 2,
            child: _SectionCard(
              title: 'Classe',
              icon: Icons.school_rounded,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: classes
                    .map(
                      (c) => _ClassChip(
                        label: c.name,
                        selected: selectedClassId == c.id,
                        onTap: () => onChanged(c.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
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
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration(const Duration(milliseconds: 180)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? accent
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
