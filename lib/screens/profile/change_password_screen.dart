import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/loading_overlay.dart';
import '../../common/password_strength.dart';
import '../../core/theme.dart';
import '../../providers/service_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Robustesse du nouveau mot de passe : 0 (vide) → 4 (très solide).
  int get _strength => passwordStrength(_newCtrl.text);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authServiceProvider).changePasswordWithVerification(
            _oldCtrl.text,
            _newCtrl.text,
          );
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, 'Mot de passe modifié !');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppFeedback.error(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;

    return LoadingOverlay(
      isLoading: _submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Changer le mot de passe')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // ── En-tête ─────────────────────────────────────────────────
                FadeSlideIn.staggered(
                  index: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.black, 0.25)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: context.onAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sécurité du compte',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Le nouveau mot de passe doit contenir '
                                'au moins 8 caractères.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Champs ─────────────────────────────────────────────────
                FadeSlideIn.staggered(
                  index: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _oldCtrl,
                            obscureText: _obscureOld,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe actuel',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() {
                                  _obscureOld = !_obscureOld;
                                }),
                                icon: Icon(
                                  _obscureOld
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Mot de passe actuel requis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _newCtrl,
                            obscureText: _obscureNew,
                            decoration: InputDecoration(
                              labelText: 'Nouveau mot de passe',
                              prefixIcon: const Icon(Icons.key_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() {
                                  _obscureNew = !_obscureNew;
                                }),
                                icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Au moins 8 caractères';
                              }
                              return null;
                            },
                          ),
                          // ── Robustesse ─────────────────────────────────
                          if (_newCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            PasswordStrengthBar(strength: _strength),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirmer le mot de passe',
                              prefixIcon:
                                  const Icon(Icons.check_circle_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() {
                                  _obscureConfirm = !_obscureConfirm;
                                }),
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value != _newCtrl.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
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
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Mettre à jour'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}

