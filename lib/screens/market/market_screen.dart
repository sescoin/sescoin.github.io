import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/animations.dart';
import '../../common/app_feedback.dart';
import '../../common/ban_guard.dart';
import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../market/auction_card.dart';
import '../../market/market_item_card.dart';
import '../../models/marketplace_item.dart';
import '../../providers/auction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/service_providers.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(
      () => ref.read(auctionServiceProvider).finalizeExpiredAuctions(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marché'),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => context.push(
                '${AppRoutes.adminMarketEdit}?tab=${_tabController.index == 1 ? 'auctions' : 'shop'}',
              ),
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Gérer le marché',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Boutique', icon: Icon(Icons.storefront_rounded)),
            Tab(text: 'Enchères', icon: Icon(Icons.gavel_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ShopTab(),
          _AuctionsTab(),
        ],
      ),
    );
  }
}

class _ShopTab extends ConsumerWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(marketplaceItemsProvider);
    final purchaseHistoryAsync = ref.watch(purchaseHistoryProvider);
    final purchaseState = ref.watch(purchaseProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 680
            ? 3
            : 2;

    return itemsAsync.when(
      loading: () => const InlineLoader(message: 'Chargement du marché...'),
      error: (error, _) => ErrorRetry(
        message: 'Impossible de charger le marché',
        onRetry: () => ref.invalidate(marketplaceItemsProvider),
      ),
      data: (items) {
        final purchaseCounts = purchaseHistoryAsync.maybeWhen(
          data: (purchases) {
            final counts = <String, int>{};
            for (final purchase in purchases) {
              final itemId = purchase['item_id'] as String?;
              if (itemId == null) {
                continue;
              }
              counts[itemId] =
                  (counts[itemId] ?? 0) + (purchase['quantity'] as int? ?? 0);
            }
            return counts;
          },
          orElse: () => const <String, int>{},
        );

        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_rounded,
            title: 'Boutique vide',
            subtitle: 'Les offres actives apparaîtront ici',
          );
        }

        // Regroupe par catégorie. Les catégories à une seule offre sont
        // rassemblées dans une grille commune (côte à côte), les catégories
        // à plusieurs offres gardent leur propre section.
        final grouped = <String, List<MarketplaceItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        final multiCategories = grouped.entries
            .where((e) => e.value.length > 1)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final singleItems = (grouped.entries
                .where((e) => e.value.length == 1)
                .map((e) => e.value.first)
                .toList())
          ..sort((a, b) => a.category.compareTo(b.category));

        Widget buildCard(MarketplaceItem item) {
          final alreadyBought = purchaseCounts[item.id] ?? 0;
          final hasReachedPurchaseLimit =
              item.hasPurchaseLimit && alreadyBought >= item.maxPerUser;
          return MarketItemCard(
            item: item,
            fillHeight: true,
            actionLabel: hasReachedPurchaseLimit ? 'Limite atteinte' : null,
            isLoading: purchaseState.isLoading &&
                purchaseState.loadingItemId == item.id,
            onBuy: hasReachedPurchaseLimit
                ? null
                : () => _confirmPurchase(context, ref, item),
          );
        }

        Widget buildGrid(List<MarketplaceItem> gridItems) {
          const spacing = 12.0;
          // Lignes de `crossAxisCount` cartes, chacune étirée à la hauteur de
          // la plus grande de sa ligne (IntrinsicHeight + stretch).
          final rows = <Widget>[];
          for (var i = 0; i < gridItems.length; i += crossAxisCount) {
            final rowItems = gridItems.sublist(
              i,
              (i + crossAxisCount).clamp(0, gridItems.length),
            );
            final cells = <Widget>[];
            for (var j = 0; j < crossAxisCount; j++) {
              if (j > 0) cells.add(const SizedBox(width: spacing));
              cells.add(
                Expanded(
                  child: j < rowItems.length
                      ? buildCard(rowItems[j])
                      : const SizedBox.shrink(),
                ),
              );
            }
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cells,
                  ),
                ),
              ),
            );
          }
          return Column(children: rows);
        }

        return LoadingOverlay(
          isLoading: purchaseState.isLoading,
          message: 'Achat en cours...',
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in multiCategories) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                        ),
                  ),
                ),
                buildGrid(entry.value),
                const SizedBox(height: 8),
              ],
              if (singleItems.isNotEmpty) ...[
                if (multiCategories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Autres offres',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                    ),
                  )
                else
                  const SizedBox(height: 4),
                buildGrid(singleItems),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmPurchase(
    BuildContext context,
    WidgetRef ref,
    MarketplaceItem item,
  ) async {
    if (!ensureNotBanned(context, ref)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer l\'achat'),
        content: Text(
          'Acheter "${item.name}" pour ${item.price.toStringAsFixed(2)} SC ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Acheter'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(purchaseProvider.notifier).purchase(itemId: item.id);
      if (context.mounted) {
        AppFeedback.success(context, 'Achat effectué : ${item.name}.');
      }
    } catch (error) {
      if (context.mounted) {
        AppFeedback.error(context, error);
      }
    }
  }
}

class _AuctionsTab extends ConsumerWidget {
  const _AuctionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(activeAuctionsProvider);
    final bidState = ref.watch(bidProvider);

    return auctionsAsync.when(
      loading: () => const InlineLoader(message: 'Chargement des enchères...'),
      error: (error, _) => ErrorRetry(
        message: 'Impossible de charger les enchères',
        onRetry: () => ref.invalidate(activeAuctionsProvider),
      ),
      data: (auctions) {
        if (auctions.isEmpty) {
          return const EmptyState(
            icon: Icons.gavel_rounded,
            title: 'Aucune enchère',
            subtitle: 'Les enchères actives apparaîtront ici',
          );
        }

        return LoadingOverlay(
          isLoading: bidState.isLoading,
          message: 'Enchère en cours...',
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: auctions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => FadeSlideIn.staggered(
              key: ValueKey(auctions[index].id),
              index: index,
              child: AuctionCard(
                auction: auctions[index],
                isLoading: bidState.isLoading,
                onBid: () => context.push('/auction/${auctions[index].id}'),
              ),
            ),
          ),
        );
      },
    );
  }
}
