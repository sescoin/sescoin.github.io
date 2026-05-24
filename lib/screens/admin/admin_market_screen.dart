import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/auction.dart';
import '../../models/marketplace_item.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auction_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/service_providers.dart';

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
                    subtitle: 'Ajoutez la première offre du marché',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ItemAdminCard(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemAdminCard extends ConsumerWidget {
  const _ItemAdminCard({required this.item});

  final MarketplaceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!item.isActive)
                  const _TinyBadge(
                    label: 'Inactif',
                    color: AppTheme.negative,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.category} · ${item.price.toStringAsFixed(2)} SC · stock ${item.stock}',
              style: const TextStyle(fontSize: 12),
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.adminMarketEditItem.replaceFirst(':itemId', item.id),
                    extra: item,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showBuyers(context, ref, item),
                  icon: const Icon(Icons.groups_rounded, size: 18),
                  label: const Text('Acheteurs'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(adminActionsProvider.notifier)
                      .deleteItem(item.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.negative,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBuyers(
    BuildContext context,
    WidgetRef ref,
    MarketplaceItem item,
  ) async {
    final buyers = await ref.read(marketplaceServiceProvider).getItemBuyers(item.id);
    if (!context.mounted) {
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acheteurs de ${item.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Les achats futurs gardent leur propre snapshot même si l’offre change ensuite.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: buyers.isEmpty
                      ? const EmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Aucun achat',
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: buyers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final purchase = buyers[index];
                            final buyer =
                                purchase['buyer'] as Map<String, dynamic>? ?? {};
                            final snapshotName =
                                purchase['item_name_snapshot'] as String? ?? item.name;
                            final unitPrice = (purchase['unit_price_snapshot'] as num?)
                                    ?.toDouble() ??
                                item.price;
                            return ListTile(
                              leading: UserAvatar(
                                username: buyer['username'] as String? ?? 'inconnu',
                                avatarUrl: buyer['avatar_url'] as String?,
                                radius: 18,
                              ),
                              title: Text(
                                buyer['display_name'] as String? ??
                                    buyer['username'] as String? ??
                                    'Acheteur inconnu',
                              ),
                              subtitle: Text(
                                '$snapshotName · x${purchase['quantity']} · ${dateFormat.format(DateTime.parse(purchase['created_at'] as String).toLocal())}',
                              ),
                              trailing: Text(
                                '${unitPrice.toStringAsFixed(2)} SC',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.gold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAuctionsTab extends ConsumerWidget {
  const _AdminAuctionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctionsAsync = ref.watch(allAuctionsProvider);

    return auctionsAsync.when(
      loading: () => const InlineLoader(),
      error: (e, _) => ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(allAuctionsProvider),
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
                    subtitle: 'Créez la première enchère',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: auctions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final auction = auctions[index];
                      return _AuctionAdminCard(auction: auction);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AuctionAdminCard extends ConsumerWidget {
  const _AuctionAdminCard({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    auction.itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _TinyBadge(
                  label: switch (auction.status) {
                    AuctionStatus.upcoming => 'À venir',
                    AuctionStatus.active => 'Active',
                    AuctionStatus.ended => 'Terminée',
                    AuctionStatus.cancelled => 'Annulée',
                  },
                  color: switch (auction.status) {
                    AuctionStatus.upcoming => AppTheme.warning,
                    AuctionStatus.active => AppTheme.positive,
                    AuctionStatus.ended => AppTheme.gold,
                    AuctionStatus.cancelled => AppTheme.negative,
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Prix actuel ${auction.currentPrice.toStringAsFixed(2)} SC · fin ${DateFormat('dd/MM/yyyy HH:mm').format(auction.endsAt)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (auction.currentWinnerUsername != null) ...[
              const SizedBox(height: 4),
              Text(
                'En tête : @${auction.currentWinnerUsername}${auction.currentWinnerEmoji != null ? ' ${auction.currentWinnerEmoji}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAuctionResults(context, ref, auction),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Résultat'),
                ),
                if (auction.isActive || auction.isUpcoming)
                  OutlinedButton(
                    onPressed: () => ref
                        .read(adminActionsProvider.notifier)
                        .cancelAuction(auction.id),
                    child: const Text('Annuler'),
                  ),
                if (auction.isActive)
                  ElevatedButton(
                    onPressed: () => ref
                        .read(adminActionsProvider.notifier)
                        .finalizeAuction(auction.id),
                    child: const Text('Clôturer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAuctionResults(
    BuildContext context,
    WidgetRef ref,
    Auction auction,
  ) async {
    final bids =
        await ref.read(auctionServiceProvider).getAuctionBidHistory(auction.id);
    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résultat de ${auction.itemName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (auction.currentWinnerUsername != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Gagnant : @${auction.currentWinnerUsername} · ${auction.currentPrice.toStringAsFixed(2)} SC',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (auction.currentWinnerUsername == null)
                  const EmptyState(
                    icon: Icons.gavel_rounded,
                    title: 'Aucun gagnant pour le moment',
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: bids.isEmpty
                      ? const EmptyState(
                          icon: Icons.list_alt_rounded,
                          title: 'Aucune offre enregistrée',
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: bids.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final bid = bids[index];
                            final bidder =
                                bid['bidder'] as Map<String, dynamic>? ?? {};
                            final isWinner =
                                bidder['id'] == auction.currentWinnerId;
                            return ListTile(
                              leading: UserAvatar(
                                username: bidder['username'] as String? ?? 'inconnu',
                                avatarUrl: bidder['avatar_url'] as String?,
                                radius: 18,
                              ),
                              title: Text(
                                bidder['display_name'] as String? ??
                                    bidder['username'] as String? ??
                                    'Utilisateur inconnu',
                              ),
                              subtitle: Text('@${bid['bidder_username']}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(bid['amount'] as num).toDouble().toStringAsFixed(2)} SC',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isWinner ? AppTheme.gold : null,
                                    ),
                                  ),
                                  if (isWinner)
                                    const Text(
                                      'Gagnant',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
