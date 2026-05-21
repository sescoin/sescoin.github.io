import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/theme.dart';
import '../../providers/wallet_provider.dart';
import '../../transaction/transaction_tile.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(walletProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille'),
        actions: [
          IconButton(
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isRefreshing && state.items.isEmpty) {
            return const InlineLoader(message: 'Chargement...');
          }

          if (state.error != null && state.items.isEmpty) {
            return ErrorRetry(
              message: 'Impossible de charger les transactions',
              onRetry: () => ref.read(walletProvider.notifier).loadInitial(),
            );
          }

          if (!state.isRefreshing && state.items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Aucune transaction',
              subtitle: 'Tes transactions apparaîtront ici',
            );
          }

          return RefreshIndicator(
            color: AppTheme.gold,
            onRefresh: () => ref.read(walletProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, i) {
                if (i == state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.gold,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                return TransactionTile(transaction: state.items[i]);
              },
            ),
          );
        },
      ),
    );
  }
}
