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

enum _TransactionSort { newest, oldest, amountHigh, amountLow }

class TransactionExplorerScreen extends ConsumerStatefulWidget {
  const TransactionExplorerScreen({super.key});

  @override
  ConsumerState<TransactionExplorerScreen> createState() =>
      _TransactionExplorerScreenState();
}

class _TransactionExplorerScreenState
    extends ConsumerState<TransactionExplorerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  String _query = '';
  TransactionType? _selectedType;
  String? _selectedPaymentMethod;
  _TransactionSort _sort = _TransactionSort.newest;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(globalTransactionsProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Blockchain'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              tooltip: 'Filtres',
              icon: Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: Text('$_activeFilterCount'),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ],
      ),
      endDrawer: _ExplorerDrawer(
        searchController: _searchController,
        minAmountController: _minAmountController,
        maxAmountController: _maxAmountController,
        query: _query,
        selectedType: _selectedType,
        selectedPaymentMethod: _selectedPaymentMethod,
        sort: _sort,
        startDate: _startDate,
        endDate: _endDate,
        hasActiveFilters: _hasActiveFilters,
        onQueryChanged: (value) => setState(() => _query = value.trim()),
        onAmountChanged: () => setState(() {}),
        onTypeChanged: (value) => setState(() => _selectedType = value),
        onPaymentMethodChanged: (value) =>
            setState(() => _selectedPaymentMethod = value),
        onSortChanged: (value) => setState(() => _sort = value),
        onPickStartDate: _pickStartDate,
        onPickEndDate: _pickEndDate,
        onReset: _resetFilters,
      ),
      body: LoadingOverlay(
        isLoading: false,
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorRetry(
            message: 'Impossible de charger le flux des transactions',
            onRetry: () => ref.invalidate(globalTransactionsProvider),
          ),
          data: (transactions) {
            final filtered = transactions.where(_matchesFilters).toList()
              ..sort(_compareTransactions);
            final uniqueUsers = <String>{
              for (final tx in filtered) ...[
                if (tx.fromUsername != null) tx.fromUsername!,
                if (tx.toUsername != null) tx.toUsername!,
              ],
            }.length;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(globalTransactionsProvider);
                ref.invalidate(globalTransactionsSnapshotProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _ExplorerHeader(
                    totalTransactions: filtered.length,
                    totalUsers: uniqueUsers,
                    query: _query,
                    activeFilterCount: _activeFilterCount,
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.hub_rounded,
                      title: 'Aucune transaction trouvée',
                      subtitle:
                          'Essaie un autre filtre ou élargis la recherche',
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
            );
          },
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _selectedType != null ||
      _selectedPaymentMethod != null ||
      _minAmountController.text.trim().isNotEmpty ||
      _maxAmountController.text.trim().isNotEmpty ||
      _startDate != null ||
      _endDate != null ||
      _sort != _TransactionSort.newest;

  int get _activeFilterCount {
    var count = 0;
    if (_query.isNotEmpty) {
      count++;
    }
    if (_selectedType != null) {
      count++;
    }
    if (_selectedPaymentMethod != null) {
      count++;
    }
    if (_minAmountController.text.trim().isNotEmpty) {
      count++;
    }
    if (_maxAmountController.text.trim().isNotEmpty) {
      count++;
    }
    if (_startDate != null) {
      count++;
    }
    if (_endDate != null) {
      count++;
    }
    if (_sort != _TransactionSort.newest) {
      count++;
    }
    return count;
  }

  bool _matchesFilters(Transaction transaction) {
    return _matchesQuery(transaction) &&
        _matchesType(transaction) &&
        _matchesPaymentMethod(transaction) &&
        _matchesAmount(transaction) &&
        _matchesDate(transaction);
  }

  bool _matchesQuery(Transaction transaction) {
    if (_query.isEmpty) {
      return true;
    }

    final query = _normalize(_query);
    final haystack = [
      transaction.fromUsername,
      transaction.toUsername,
      transaction.fromDisplayName,
      transaction.toDisplayName,
      transaction.description,
      transaction.type.label,
      transaction.paymentMethodLabel,
    ].whereType<String>().map(_normalize).join(' ');

    return haystack.contains(query);
  }

  bool _matchesType(Transaction transaction) {
    return _selectedType == null || transaction.type == _selectedType;
  }

  bool _matchesPaymentMethod(Transaction transaction) {
    return _selectedPaymentMethod == null ||
        transaction.paymentMethod == _selectedPaymentMethod;
  }

  bool _matchesAmount(Transaction transaction) {
    final min = double.tryParse(_minAmountController.text.replaceAll(',', '.'));
    final max = double.tryParse(_maxAmountController.text.replaceAll(',', '.'));

    if (min != null && transaction.amount < min) {
      return false;
    }
    if (max != null && transaction.amount > max) {
      return false;
    }
    return true;
  }

  bool _matchesDate(Transaction transaction) {
    final localDate = transaction.createdAt.toLocal();

    if (_startDate != null) {
      final start =
          DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (localDate.isBefore(start)) {
        return false;
      }
    }

    if (_endDate != null) {
      final end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      if (localDate.isAfter(end)) {
        return false;
      }
    }

    return true;
  }

  int _compareTransactions(Transaction a, Transaction b) {
    return switch (_sort) {
      _TransactionSort.newest => b.createdAt.compareTo(a.createdAt),
      _TransactionSort.oldest => a.createdAt.compareTo(b.createdAt),
      _TransactionSort.amountHigh => b.amount.compareTo(a.amount),
      _TransactionSort.amountLow => a.amount.compareTo(b.amount),
    };
  }

  String _normalize(String value) {
    const replacements = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'À': 'a',
      'Â': 'a',
      'Ä': 'a',
      'Á': 'a',
      'Ç': 'c',
      'È': 'e',
      'É': 'e',
      'Ê': 'e',
      'Ë': 'e',
      'Ì': 'i',
      'Í': 'i',
      'Î': 'i',
      'Ï': 'i',
      'Ò': 'o',
      'Ó': 'o',
      'Ô': 'o',
      'Ö': 'o',
      'Õ': 'o',
      'Ù': 'u',
      'Ú': 'u',
      'Û': 'u',
      'Ü': 'u',
    };

    var result = value.toLowerCase();
    replacements.forEach((source, target) {
      result = result.replaceAll(source, target);
    });
    return result;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _resetFilters() {
    _searchController.clear();
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
      _query = '';
      _selectedType = null;
      _selectedPaymentMethod = null;
      _sort = _TransactionSort.newest;
      _startDate = null;
      _endDate = null;
    });
  }

  void _openProfile(String username) {
    context.push(AppRoutes.publicProfilePath(username));
  }
}

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({
    required this.totalTransactions,
    required this.totalUsers,
    required this.query,
    required this.activeFilterCount,
  });

  final int totalTransactions;
  final int totalUsers;
  final String query;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final hasFilters = activeFilterCount > 0;

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
                    hasQuery || hasFilters
                        ? 'Résultats filtrés'
                        : 'Flux global des transactions',
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
                  if (hasQuery) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Recherche : "$query"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerDrawer extends StatelessWidget {
  const _ExplorerDrawer({
    required this.searchController,
    required this.minAmountController,
    required this.maxAmountController,
    required this.query,
    required this.selectedType,
    required this.selectedPaymentMethod,
    required this.sort,
    required this.startDate,
    required this.endDate,
    required this.hasActiveFilters,
    required this.onQueryChanged,
    required this.onAmountChanged,
    required this.onTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onSortChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onReset,
  });

  final TextEditingController searchController;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final String query;
  final TransactionType? selectedType;
  final String? selectedPaymentMethod;
  final _TransactionSort sort;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasActiveFilters;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAmountChanged;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final ValueChanged<_TransactionSort> onSortChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtres blockchain',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      labelText: 'Utilisateur, raison ou note',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => onAmountChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Montant min.',
                            suffixText: 'SC',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => onAmountChanged(),
                          decoration: const InputDecoration(
                            labelText: 'Montant max.',
                            suffixText: 'SC',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<_TransactionSort>(
                    initialValue: sort,
                    decoration: const InputDecoration(labelText: 'Trier par'),
                    items: const [
                      DropdownMenuItem(
                        value: _TransactionSort.newest,
                        child: Text('Date décroissante'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.oldest,
                        child: Text('Date croissante'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.amountHigh,
                        child: Text('Montant décroissant'),
                      ),
                      DropdownMenuItem(
                        value: _TransactionSort.amountLow,
                        child: Text('Montant croissant'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onSortChanged(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType?>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      const DropdownMenuItem<TransactionType?>(
                        value: null,
                        child: Text('Tous les types'),
                      ),
                      ...TransactionType.values.map(
                        (type) => DropdownMenuItem<TransactionType?>(
                          value: type,
                          child: Text(type.label),
                        ),
                      ),
                    ],
                    onChanged: onTypeChanged,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Paiement QR / NFC',
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'nfc',
                        child: Text('NFC'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'qr',
                        child: Text('QR'),
                      ),
                    ],
                    onChanged: onPaymentMethodChanged,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onPickStartDate,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      startDate == null
                          ? 'Date minimum'
                          : 'Depuis le ${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onPickEndDate,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(
                      endDate == null
                          ? 'Date maximum'
                          : 'Jusqu\'au ${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Appliquer'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: hasActiveFilters ? onReset : null,
                    child: const Text('Réinitialiser'),
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
