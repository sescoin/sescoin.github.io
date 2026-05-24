import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Overlay de chargement à poser sur n'importe quel widget
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.16),
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: AppTheme.gold,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Version simple inline (pas d'overlay, juste un indicateur centré)
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 3),
      ),
    );
  }
}
