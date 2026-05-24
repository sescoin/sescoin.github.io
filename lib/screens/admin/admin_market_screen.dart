import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auction_provider.dart';
import '../../providers/marketplace_provider.dart';

class AdminMarketScreen extends ConsumerStatefulWidget {
  const AdminMarketScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  ConsumerState<AdminMarketScreen> createState() => _AdminMarketScreenState();
}

class _AdminMarketScreenState extends ConsumerState<AdminMarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gérer le marché'),
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            tabs: const [
              Tab(text: 'Boutique', icon: Icon(Icons.storefront_rounded)),
              Tab(text: 'Enchères', icon: Icon(Icons.gavel_rounded)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _AdminShopTab(),
            _AdminAuctionsTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminShopTab extends ConsumerWidget {
  const _AdminShopTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(marketplaceItemsProvider);

    return itemsAsync.when(
      loading: () => const InlineLoader(),
      error: (e, _) => ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(marketplaceItemsProvider),
      ),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.adminMarketNewItem),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter une offre boutique'),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.storefront_rounded,
                    title: 'Aucune offre boutique',
                    subtitle: 'Ajoute la première offre du marché',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.category} · ${item.price.toStringAsFixed(2)} SC · stock ${item.stock}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: AppTheme.negative,
                            onPressed: () => _deleteItem(context, ref, item.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    await ref.read(adminActionsProvider.notifier).deleteItem(itemId);
  }
}

class _AdminAuctionsTab extends ConsumerWidget {
  const _AdminAuctionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(activeAuctionsProvider);

    return auctionsAsync.when(
      loading: () => const InlineLoader(),
      error: (e, _) => ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(activeAuctionsProvider),
      ),
      data: (auctions) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.adminMarketNewAuction),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer une enchère'),
              ),
            ),
          ),
          Expanded(
            child: auctions.isEmpty
                ? const EmptyState(
                    icon: Icons.gavel_rounded,
                    title: 'Aucune enchère',
                    subtitle: 'Crée la première enchère',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: auctions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final auction = auctions[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auction.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Prix actuel ${auction.currentPrice.toStringAsFixed(2)} SC · fin ${auction.endsAt.toLocal()}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (auction.currentWinnerUsername != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Dernier enchérisseur : @${auction.currentWinnerUsername}${auction.currentWinnerEmoji != null ? ' ${auction.currentWinnerEmoji}' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => ref
                                          .read(adminActionsProvider.notifier)
                                          .cancelAuction(auction.id),
                                      child: const Text('Annuler'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => ref
                                          .read(adminActionsProvider.notifier)
                                          .finalizeAuction(auction.id),
                                      child: const Text('Clôturer'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
