import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/router.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_explorer_provider.dart';
import '../../transaction/global_transaction_tile.dart';

class TransactionExplorerScreen extends ConsumerStatefulWidget {
  const TransactionExplorerScreen({super.key});

  @override
  ConsumerState<TransactionExplorerScreen> createState() =>
      _TransactionExplorerScreenState();
}

class _TransactionExplorerScreenState
    extends ConsumerState<TransactionExplorerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(globalTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Explorateur de transactions')),
      body: LoadingOverlay(
        isLoading: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur, un type ou une note',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            feedAsync.when(
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Expanded(
                child: ErrorRetry(
                  message: 'Impossible de charger le flux des transactions',
                  onRetry: () => ref.invalidate(globalTransactionsProvider),
                ),
              ),
              data: (transactions) {
                final filtered = transactions.where(_matchesQuery).toList();
                final uniqueUsers = <String>{
                  for (final tx in filtered) ...[
                    if (tx.fromUsername != null) tx.fromUsername!,
                    if (tx.toUsername != null) tx.toUsername!,
                  ],
                }.length;

                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(globalTransactionsProvider);
                      ref.invalidate(globalTransactionsSnapshotProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _ExplorerHeader(
                          totalTransactions: filtered.length,
                          totalUsers: uniqueUsers,
                          isFiltered: _query.isNotEmpty,
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          const EmptyState(
                            icon: Icons.hub_rounded,
                            title: 'Aucune transaction trouvée',
                            subtitle:
                                'Essaie un autre nom d’utilisateur ou enlève le filtre',
                          )
                        else
                          ...filtered.map(
                            (transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlobalTransactionTile(
                                transaction: transaction,
                                onFromTap: transaction.fromUsername == null
                                    ? null
                                    : () => _openProfile(transaction.fromUsername!),
                                onToTap: transaction.toUsername == null
                                    ? null
                                    : () => _openProfile(transaction.toUsername!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(Transaction transaction) {
    if (_query.isEmpty) {
      return true;
    }

    final query = _query.toLowerCase();
    final haystack = [
      transaction.fromUsername,
      transaction.toUsername,
      transaction.fromDisplayName,
      transaction.toDisplayName,
      transaction.description,
      transaction.type.label,
    ]
        .whereType<String>()
        .join(' ')
        .toLowerCase();

    return haystack.contains(query);
  }

  void _openProfile(String username) {
    context.push(AppRoutes.publicProfilePath(username));
  }
}

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({
    required this.totalTransactions,
    required this.totalUsers,
    required this.isFiltered,
  });

  final int totalTransactions;
  final int totalUsers;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.hub_rounded, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFiltered ? 'Résultats filtrés' : 'Flux global en direct',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalTransactions transaction(s) · $totalUsers utilisateur(s)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
