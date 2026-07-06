import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/empty_state.dart';
import '../../common/error_retry.dart';
import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
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
        onTypeChanged: (value) => setState(() {
          _selectedType = value;
          // La méthode de paiement (QR/NFC) ne concerne que les virements.
          if (value != null && value != TransactionType.transfer) {
            _selectedPaymentMethod = null;
          }
        }),
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

// ── Section de filtre (en-tête icône + titre) ─────────────────────────────────

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Puce de filtre sélectionnable ─────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent
                : Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? accent
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
    final accent = context.accent;
    // Le paiement QR/NFC n'existe que sur les virements.
    final paymentEnabled =
        selectedType == null || selectedType == TransactionType.transfer;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.tune_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filtres',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _FilterSection(
                    icon: Icons.search_rounded,
                    title: 'Recherche',
                    accent: accent,
                    child: TextField(
                      controller: searchController,
                      onChanged: onQueryChanged,
                      decoration: InputDecoration(
                        hintText: 'Utilisateur, raison ou note',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  onQueryChanged('');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                      ),
                    ),
                  ),
                  _FilterSection(
                    icon: Icons.payments_rounded,
                    title: 'Montant',
                    accent: accent,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minAmountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => onAmountChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Min.',
                              suffixText: 'SC',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxAmountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => onAmountChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Max.',
                              suffixText: 'SC',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FilterSection(
                    icon: Icons.category_rounded,
                    title: 'Type de transaction',
                    accent: accent,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: selectedType == null,
                          accent: accent,
                          onTap: () => onTypeChanged(null),
                        ),
                        ...TransactionType.values.map(
                          (type) => _FilterChip(
                            label: type.label,
                            selected: selectedType == type,
                            accent: accent,
                            onTap: () => onTypeChanged(type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FilterSection(
                    icon: Icons.contactless_rounded,
                    title: 'Méthode de paiement',
                    accent: accent,
                    subtitle: paymentEnabled
                        ? null
                        : 'Uniquement pour les virements',
                    child: Opacity(
                      opacity: paymentEnabled ? 1 : 0.4,
                      child: IgnorePointer(
                        ignoring: !paymentEnabled,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Toutes',
                              selected: selectedPaymentMethod == null,
                              accent: accent,
                              onTap: () => onPaymentMethodChanged(null),
                            ),
                            _FilterChip(
                              label: 'NFC',
                              selected: selectedPaymentMethod == 'nfc',
                              accent: accent,
                              onTap: () => onPaymentMethodChanged('nfc'),
                            ),
                            _FilterChip(
                              label: 'QR',
                              selected: selectedPaymentMethod == 'qr',
                              accent: accent,
                              onTap: () => onPaymentMethodChanged('qr'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _FilterSection(
                    icon: Icons.sort_rounded,
                    title: 'Trier par',
                    accent: accent,
                    child: DropdownButtonFormField<_TransactionSort>(
                      initialValue: sort,
                      decoration: const InputDecoration(isDense: true),
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
                  ),
                  _FilterSection(
                    icon: Icons.date_range_rounded,
                    title: 'Période',
                    accent: accent,
                    child: Column(
                      children: [
                        OutlinedButton.icon(
                          onPressed: onPickStartDate,
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(
                            startDate == null
                                ? 'Date minimum'
                                : 'Depuis le ${startDate!.day.toString().padLeft(2, '0')}/${startDate!.month.toString().padLeft(2, '0')}/${startDate!.year}',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: onPickEndDate,
                          icon:
                              const Icon(Icons.event_available_rounded, size: 18),
                          label: Text(
                            endDate == null
                                ? 'Date maximum'
                                : 'Jusqu\'au ${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ],
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
