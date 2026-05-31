import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../common/user_avatar.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/service_providers.dart';

final adminPurchaseHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(marketplaceServiceProvider).getAllPurchaseHistory();
});

final adminAuctionHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(auctionServiceProvider).getAllAuctionBidHistory();
});

class AdminMarketHistoryScreen extends ConsumerWidget {
  const AdminMarketHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminActionsProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Historique du marché'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Offres', icon: Icon(Icons.storefront_rounded)),
                Tab(text: 'Enchères', icon: Icon(Icons.gavel_rounded)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _PurchaseHistoryTab(),
              _AuctionHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistoryTab extends ConsumerWidget {
  const _PurchaseHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(adminPurchaseHistoryProvider);

    return purchasesAsync.when(
      loading: () => const InlineLoader(),
      error: (error, _) => ErrorRetry(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminPurchaseHistoryProvider),
      ),
      data: (purchases) {
        if (purchases.isEmpty) {
          return const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Aucun achat',
            subtitle: "Les achats d'offres apparaîtront ici",
          );
        }

        final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: purchases.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final purchase = purchases[index];
            final buyer = purchase['buyer'] as Map<String, dynamic>? ?? {};
            final item = purchase['item'] as Map<String, dynamic>?;
            final buyerUsername = buyer['username'] as String? ??
                purchase['buyer_username_snapshot'] as String? ??
                'inconnu';
            final buyerName = buyer['display_name'] as String? ?? buyerUsername;
            final itemName = purchase['item_name_snapshot'] as String? ??
                item?['name'] as String? ??
                'Offre supprimée';

            return Card(
              child: ListTile(
                leading: UserAvatar(
                  username: buyerUsername,
                  avatarUrl: buyer['avatar_url'] as String?,
                  radius: 20,
                ),
                title: Text(
                  itemName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Acheté par $buyerName · x${purchase['quantity']} · '
                  '${dateFormat.format(DateTime.parse(purchase['created_at'] as String).toLocal())}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(purchase['total_price'] as num).toDouble().toStringAsFixed(2)} SC',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold,
                      ),
                    ),
                    if (purchase['item_id'] == null)
                      const Text(
                        'Offre supprimée',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.negative,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuctionHistoryTab extends ConsumerWidget {
  const _AuctionHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(adminAuctionHistoryProvider);

    return bidsAsync.when(
      loading: () => const InlineLoader(),
      error: (error, _) => ErrorRetry(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminAuctionHistoryProvider),
      ),
      data: (bids) {
        if (bids.isEmpty) {
          return const EmptyState(
            icon: Icons.gavel_rounded,
            title: 'Aucune enchère',
            subtitle: "Les offres d'enchères apparaîtront ici",
          );
        }

        final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bids.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final bid = bids[index];
            final bidder = bid['bidder'] as Map<String, dynamic>? ?? {};
            final auction = bid['auction'] as Map<String, dynamic>?;
            final bidderUsername = bidder['username'] as String? ??
                bid['bidder_username'] as String? ??
                'inconnu';
            final bidderName =
                bidder['display_name'] as String? ?? bidderUsername;
            final auctionName = auction?['item_name'] as String? ??
                bid['auction_item_name_snapshot'] as String? ??
                'Enchère supprimée';

            return Card(
              child: ListTile(
                leading: UserAvatar(
                  username: bidderUsername,
                  avatarUrl: bidder['avatar_url'] as String?,
                  radius: 20,
                ),
                title: Text(
                  auctionName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Enchère par $bidderName · '
                  '${dateFormat.format(DateTime.parse(bid['created_at'] as String).toLocal())}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(bid['amount'] as num).toDouble().toStringAsFixed(2)} SC',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold,
                      ),
                    ),
                    if (bid['auction_id'] == null)
                      const Text(
                        'Enchère supprimée',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.negative,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
