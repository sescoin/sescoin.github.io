import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
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
    final purchaseState = ref.watch(purchaseProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 4 : width >= 680 ? 3 : 2;
    final childAspectRatio = crossAxisCount == 2 ? 0.54 : 0.62;

    return itemsAsync.when(
      loading: () => const InlineLoader(message: 'Chargement du marché...'),
      error: (error, _) => ErrorRetry(
        message: 'Impossible de charger le marché',
        onRetry: () => ref.invalidate(marketplaceItemsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_rounded,
            title: 'Boutique vide',
            subtitle: 'La professeure n\'a pas encore ajouté d\'offres',
          );
        }

        final categories = items.map((item) => item.category).toSet().toList()
          ..sort();

        return LoadingOverlay(
          isLoading: purchaseState.isLoading,
          message: 'Achat en cours...',
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in categories) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gold,
                        ),
                  ),
                ),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: items
                      .where((item) => item.category == category)
                      .map(
                        (item) => MarketItemCard(
                          item: item,
                          isLoading: purchaseState.isLoading &&
                              purchaseState.loadingItemId == item.id,
                          onBuy: () => _confirmPurchase(context, ref, item),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} acheté !'),
            backgroundColor: AppTheme.positive,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
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
            itemBuilder: (context, index) => AuctionCard(
              auction: auctions[index],
              isLoading: bidState.isLoading,
              onBid: () => context.push('/auction/${auctions[index].id}'),
            ),
          ),
        );
      },
    );
  }
}
