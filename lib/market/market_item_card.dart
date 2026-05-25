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
  });

  final MarketplaceItem item;
  final VoidCallback? onBuy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isUnavailable = !item.isAvailable;
    final hasDescription = item.description.trim().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  color: AppTheme.gold,
                  background: AppTheme.gold.withValues(alpha: 0.12),
                ),
                if (!item.isUnlimited)
                  _InfoBadge(
                    label: '${item.stock} restant${item.stock > 1 ? 's' : ''}',
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
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
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
                        item.isAvailable ? 'Acheter' : 'Épuisé',
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
    return Container(
      height: 116,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 36,
        color: AppTheme.gold,
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
