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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl!,
                  height: 82,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(item: item),
                ),
              )
            else
              _Placeholder(item: item),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            AmountDisplay(
              amount: item.price,
              fontSize: 18,
            ),
            if (!item.isUnlimited)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.stock} restant${item.stock > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: item.stock <= 3
                        ? AppTheme.negative
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
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
                    : const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text('Acheter'),
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
      height: 82,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.storefront_rounded,
        size: 40,
        color: AppTheme.gold,
      ),
    );
  }
}
