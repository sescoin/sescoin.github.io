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
      appBar: AppBar(title: const Text('Blockchain')),
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
                  hintText: 'Rechercher un utilisateur, une raison ou une note',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _FilterCard(
                minAmountController: _minAmountController,
                maxAmountController: _maxAmountController,
                selectedType: _selectedType,
                selectedPaymentMethod: _selectedPaymentMethod,
                sort: _sort,
                startDate: _startDate,
                endDate: _endDate,
                hasActiveFilters: _hasActiveFilters,
                onChanged: () => setState(() {}),
                onTypeChanged: (value) => setState(() => _selectedType = value),
                onPaymentMethodChanged: (value) =>
                    setState(() => _selectedPaymentMethod = value),
                onSortChanged: (value) => setState(() => _sort = value),
                onPickStartDate: _pickStartDate,
                onPickEndDate: _pickEndDate,
                onReset: _resetFilters,
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
                final filtered = transactions.where(_matchesFilters).toList()
                  ..sort(_compareTransactions);
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
                          isFiltered: _query.isNotEmpty || _hasActiveFilters,
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
                                    : () =>
                                        _openProfile(transaction.fromUsername!),
                                onToTap: transaction.toUsername == null
                                    ? null
                                    : () =>
                                        _openProfile(transaction.toUsername!),
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

  bool get _hasActiveFilters =>
      _selectedType != null ||
      _selectedPaymentMethod != null ||
      _minAmountController.text.trim().isNotEmpty ||
      _maxAmountController.text.trim().isNotEmpty ||
      _startDate != null ||
      _endDate != null ||
      _sort != _TransactionSort.newest;

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
    _minAmountController.clear();
    _maxAmountController.clear();
    setState(() {
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
                    isFiltered
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.minAmountController,
    required this.maxAmountController,
    required this.selectedType,
    required this.selectedPaymentMethod,
    required this.sort,
    required this.startDate,
    required this.endDate,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onSortChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onReset,
  });

  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final TransactionType? selectedType;
  final String? selectedPaymentMethod;
  final _TransactionSort sort;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasActiveFilters;
  final VoidCallback onChanged;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<String?> onPaymentMethodChanged;
  final ValueChanged<_TransactionSort> onSortChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final dateStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    );

    return Card(
      child: ExpansionTile(
        title: const Text(
          'Filtres et tri',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: hasActiveFilters
            ? const Text('Filtres actifs')
            : const Text('Montant, date, type, utilisateur, raison'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Montant max.',
                    suffixText: 'SC',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: selectedPaymentMethod,
            decoration: const InputDecoration(labelText: 'Paiement QR / NFC'),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPickStartDate,
                  child: Text(
                    startDate == null
                        ? 'Date min.'
                        : '${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onPickEndDate,
                  child: Text(
                    endDate == null
                        ? 'Date max.'
                        : '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasActiveFilters
                      ? 'Affinage actif sur la liste.'
                      : 'Aucun filtre avancé appliqué.',
                  style: dateStyle,
                ),
              ),
              TextButton(
                onPressed: hasActiveFilters ? onReset : null,
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
