import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';

/// Système de feedback unifié : toasts flottants avec icône, couleur
/// sémantique et message humain.
///
/// Usage :
///   AppFeedback.success(context, 'Paiement envoyé !');
///   AppFeedback.error(context, e);   // accepte une exception brute
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      color: AppTheme.positive,
    );
  }

  static void error(BuildContext context, Object error) {
    HapticFeedback.mediumImpact();
    _show(
      context,
      message: prettifyError(error),
      icon: Icons.error_rounded,
      color: AppTheme.negative,
      duration: const Duration(seconds: 5),
    );
  }

  static void warning(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      color: AppTheme.warning,
      duration: const Duration(seconds: 4),
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      color: AppTheme.info,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2136) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => messenger.hideCurrentSnackBar(),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: (isDark ? Colors.white : const Color(0xFF1A1A2E))
                      .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convertit une exception brute en message français lisible.
String prettifyError(Object error) {
  if (error is String) return _cleanup(error);

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Identifiant ou mot de passe incorrect.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Trop de tentatives. Réessaie dans quelques minutes.';
    }
    return _cleanup(error.message);
  }

  if (error is PostgrestException) {
    return _cleanup(error.message);
  }

  if (error is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. Réessaie.';
  }

  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network')) {
    return 'Pas de connexion. Vérifie ton réseau et réessaie.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Le serveur met trop de temps à répondre. Réessaie.';
  }
  if (lower.contains('jwt') || lower.contains('token has expired')) {
    return 'Session expirée. Reconnecte-toi.';
  }

  return _cleanup(raw);
}

String _cleanup(String message) {
  var m = message.trim();
  m = m.replaceFirst(RegExp(r'^Exception:\s*'), '');
  m = m.replaceFirst(RegExp(r'^PostgrestException\([^)]*\)\s*:?\s*'), '');
  // Les fonctions SQL renvoient déjà des messages français propres —
  // on retire juste le préfixe technique éventuel.
  if (m.isEmpty) return 'Une erreur est survenue. Réessaie.';
  // Majuscule initiale + point final pour un rendu propre.
  m = m[0].toUpperCase() + m.substring(1);
  if (!m.endsWith('.') && !m.endsWith('!') && !m.endsWith('?')) m = '$m.';
  return m;
}
