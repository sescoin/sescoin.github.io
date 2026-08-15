import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/marketplace_item.dart';
import '../common/amount_display.dart';

class MarketItemCard extends StatelessWidget {
  const MarketItemCard({
    super.key,
    required this.item,
    required this.onBuy,
    this.isLoading = false,
    this.actionLabel,
    this.fillHeight = false,
  });

  final MarketplaceItem item;
  final VoidCallback? onBuy;
  final bool isLoading;
  final String? actionLabel;

  /// Occupe toute la hauteur disponible (bouton d'achat aligné en bas) pour
  /// que les cartes d'une même ligne aient la même taille.
  final bool fillHeight;

  void _showFullDescription(BuildContext context) {
    final accent = context.accent;
    // Le contrôleur est partagé par la barre et la zone défilante : sans lui,
    // Scrollbar ne sait pas quelle vue elle accompagne.
    final scrollCtrl = ScrollController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.network(
                      item.imageUrl!,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${item.price.toStringAsFixed(2)} SC',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Barre toujours visible : sans elle, rien n'indiquait qu'une
                // description longue continuait plus bas.
                Flexible(
                  child: Scrollbar(
                    controller: scrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 4, 24, 12),
                      child: Text(
                        item.description,
                        style: TextStyle(
                          height: 1.45,
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(scrollCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isUnavailable = !item.isAvailable;
    final hasDescription = item.description.trim().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl!,
                  height: 116,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(item: item),
                ),
              )
            else
              _Placeholder(item: item),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoBadge(
                  label: item.category,
                  color: context.accent,
                  background: context.accent.withValues(alpha: 0.12),
                ),
                if (!item.isUnlimited)
                  _InfoBadge(
                    label: item.stock == 1
                        ? 'un restant'
                        : '${item.stock} restants',
                    color: item.stock <= 3
                        ? AppTheme.negative
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    background: (item.stock <= 3
                            ? AppTheme.negative
                            : Theme.of(context).colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.12),
                  ),
                if (item.hasPurchaseLimit)
                  _InfoBadge(
                    label: 'Max ${item.maxPerUser}/pers.',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    background: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasDescription) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showFullDescription(context),
                child: Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // Pousse le prix + bouton vers le bas pour aligner les cartes.
            if (fillHeight) const Spacer() else const SizedBox(height: 10),
            AmountDisplay(
              amount: item.price,
              fontSize: 17,
            ),
            if (isUnavailable)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Indisponible',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: item.isAvailable && !isLoading ? onBuy : null,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        actionLabel ??
                            (item.isAvailable ? 'Acheter' : 'Épuisé'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.item});

  final MarketplaceItem item;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Container(
      height: 116,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: 36,
        color: accent,
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
