import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
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
                onPressed: () => _showCreateItemDialog(context, ref),
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

  Future<void> _showCreateItemDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Divers');
    final stockCtrl = TextEditingController(text: '-1');
    final imageCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nouvelle offre boutique'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prix (SC)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Stock (-1 = illimité)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageCtrl,
                decoration:
                    const InputDecoration(labelText: 'URL image (optionnel)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(adminActionsProvider.notifier).createItem(
            name: nameCtrl.text.trim(),
            description: descCtrl.text.trim(),
            price: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
            category: categoryCtrl.text.trim().isEmpty
                ? 'Divers'
                : categoryCtrl.text.trim(),
            stock: int.tryParse(stockCtrl.text) ?? -1,
            imageUrl:
                imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
          );
    }
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
                onPressed: () => _showCreateAuctionDialog(context, ref),
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

  Future<void> _showCreateAuctionDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '24');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nouvelle enchère'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom de l’objet'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Description (optionnelle)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Prix de départ (SC)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Durée (heures)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageCtrl,
                decoration:
                    const InputDecoration(labelText: 'URL image (optionnelle)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final startsAt = DateTime.now();
      final durationHours = int.tryParse(durationCtrl.text) ?? 24;
      await ref.read(adminActionsProvider.notifier).createAuction(
            itemName: nameCtrl.text.trim(),
            itemDescription: descCtrl.text.trim(),
            startingPrice: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(hours: durationHours)),
            imageUrl:
                imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
          );
    }
  }
}
