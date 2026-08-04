import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';

/// Rédaction de la citation associée au profil.
///
/// Les règles (100 caractères, pas de caractères invisibles, langage filtré)
/// sont appliquées côté serveur ; celles reprises ici ne servent qu'à donner
/// un retour immédiat.
class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key});

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  static const _maxLength = 100;

  final _controller = TextEditingController();
  bool _submitting = false;
  bool _loaded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      AppFeedback.warning(context, 'La citation est vide.');
      return;
    }
    await _send(text, 'Citation enregistrée.');
  }

  Future<void> _delete() async {
    await _send(null, 'Citation supprimée.');
  }

  Future<void> _send(String? value, String success) async {
    setState(() => _submitting = true);
    try {
      await ref.read(profileServiceProvider).setQuote(value);
      await ref.read(currentProfileProvider.notifier).refresh();
      if (!mounted) return;
      AppFeedback.success(context, success);
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    // Pré-remplissage unique : réécrire à chaque build effacerait la saisie.
    if (!_loaded && profile != null) {
      _controller.text = profile.quote ?? '';
      _loaded = true;
    }

    final hasExisting = (profile?.quote ?? '').isNotEmpty;
    final remaining = _maxLength - _controller.text.characters.length;

    return LoadingOverlay(
      isLoading: _submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Citation')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            FadeSlideIn.staggered(
              index: 0,
              child: Text(
                'Une phrase affichée avec le profil, et au-dessus de la photo '
                'sur le podium du classement.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn.staggered(
              index: 1,
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'À écrire ici',
                  counterText: '',
                  prefixIcon: const Icon(Icons.format_quote_rounded),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn.staggered(
              index: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$remaining caractère${remaining > 1 ? 's' : ''} restant'
                  '${remaining > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: remaining < 0
                        ? AppTheme.negative
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Aperçu tel qu'il apparaîtra ailleurs dans l'application.
            if (_controller.text.trim().isNotEmpty)
              FadeSlideIn.staggered(
                index: 2,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, size: 18, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _controller.text.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FadeSlideIn.staggered(
              index: 3,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(hasExisting ? 'Modifier' : 'Enregistrer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (hasExisting) ...[
              const SizedBox(height: 10),
              FadeSlideIn.staggered(
                index: 3,
                child: TextButton.icon(
                  onPressed: _submitting ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Supprimer la citation'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.negative,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
