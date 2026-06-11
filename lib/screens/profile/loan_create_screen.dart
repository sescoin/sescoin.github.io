import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';

class LoanCreateScreen extends ConsumerStatefulWidget {
  const LoanCreateScreen({super.key});

  @override
  ConsumerState<LoanCreateScreen> createState() => _LoanCreateScreenState();
}

class _LoanCreateScreenState extends ConsumerState<LoanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  List<Map<String, dynamic>> _allUsers = [];
  final List<Map<String, dynamic>> _selectedLenders = [];
  bool _loadingUsers = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final myId = ref.read(currentUserIdProvider) ??
          Supabase.instance.client.auth.currentUser?.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name, role')
          .neq('id', myId ?? '')
          .eq('is_banned', false)
          .neq('role', 'admin')
          .order('display_name');

      if (!mounted) {
        return;
      }
      setState(() {
        _allUsers = List<Map<String, dynamic>>.from(data as List);
        _loadingUsers = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return _allUsers;
    }
    return _allUsers.where((user) {
      final username = (user['username'] as String).toLowerCase();
      final name = (user['display_name'] as String).toLowerCase();
      return username.contains(query) || name.contains(query);
    }).toList();
  }

  void _addLender(Map<String, dynamic> user) {
    if (_selectedLenders.any((lender) => lender['id'] == user['id'])) {
      return;
    }
    setState(() {
      _selectedLenders.add(user);
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _removeLender(String id) {
    setState(() {
      _selectedLenders.removeWhere((lender) => lender['id'] == id);
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ??
          DateTime.now().add(const Duration(days: 7)),
      firstDate:
          DateTime.now().add(Duration(days: AppConstants.minLoanDurationDays)),
      lastDate:
          DateTime.now().add(Duration(days: AppConstants.maxLoanDurationDays)),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    setState(() {
      _dueDate = pickedDate;
      _dueTime = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final profile = ref.read(currentProfileProvider).value;
    if (profile != null && profile.balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de demander un prêt avec un solde négatif.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLenders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un prêteur')),
      );
      return;
    }

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une date d\'échéance')),
      );
      return;
    }

    final principal =
        double.parse(_amountController.text.trim().replaceAll(',', '.'));
    final interestRate =
        double.parse(_interestController.text.trim().replaceAll(',', '.'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la demande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prêteurs : ${_selectedLenders.map((l) => l['display_name']).join(', ')}',
            ),
            const SizedBox(height: 4),
            Text('Montant : ${principal.toStringAsFixed(2)} SC'),
            Text('Intérêt : ${interestRate.toStringAsFixed(1)} %'),
            if (_dueDate != null)
              Text(() {
                final d = _dueDate!;
                final t = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
                return 'Échéance : ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
                    '  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              }()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    var sent = 0;
    final errors = <String>[];

    for (final lender in _selectedLenders) {
      try {
        final t = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
        final combinedDue = DateTime(
          _dueDate!.year, _dueDate!.month, _dueDate!.day, t.hour, t.minute,
        );
        await ref.read(loanActionProvider.notifier).requestLoan(
              lenderUsername: lender['username'] as String,
              principal: principal,
              interestRate: interestRate,
              dueDate: combinedDue,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            );
        sent++;
      } catch (error) {
        errors.add('${lender['display_name']} : $error');
      }
    }

    if (!mounted) {
      return;
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sent envoyée(s), ${errors.length} échec(s)'),
          backgroundColor:
              errors.length == _selectedLenders.length ? Colors.red : Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$sent demande(s) de prêt envoyée(s) avec succès !'),
        backgroundColor: AppTheme.positive,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanActionProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      message: 'Envoi des demandes...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Demander un prêt')),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Prêteur(s)'),
                const SizedBox(height: 8),
                if (_selectedLenders.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedLenders
                        .map(
                          (lender) => Chip(
                            avatar: CircleAvatar(
                              backgroundColor:
                                  AppTheme.gold.withValues(alpha: 0.2),
                              child: Text(
                                (lender['display_name'] as String)[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ),
                            label: Text(lender['display_name'] as String),
                            onDeleted: () => _removeLender(lender['id'] as String),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _loadingUsers
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Aucun utilisateur trouvé',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: _filteredUsers.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    final alreadySelected = _selectedLenders.any(
                                      (lender) => lender['id'] == user['id'],
                                    );

                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            AppTheme.gold.withValues(alpha: 0.15),
                                        child: Text(
                                          (user['display_name'] as String)[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.gold,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      title: Text(user['display_name'] as String),
                                      subtitle: Text(
                                        '@${user['username']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: alreadySelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: AppTheme.positive,
                                              size: 18,
                                            )
                                          : null,
                                      onTap:
                                          alreadySelected ? null : () => _addLender(user),
                                    );
                                  },
                                ),
                              ),
                            ),
                ],
                const SizedBox(height: 20),
                _Label('Montant emprunté'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    suffixText: 'SC',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      value?.trim().replaceAll(',', '.') ?? '',
                    );
                    if (amount == null || amount < AppConstants.minTransferAmount) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _Label('Taux d’intérêt'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _interestController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: '%',
                  ),
                  validator: (value) {
                    final rate = double.tryParse(
                      value?.trim().replaceAll(',', '.') ?? '',
                    );
                    if (rate == null ||
                        rate < AppConstants.minLoanInterestRate ||
                        rate > AppConstants.maxLoanInterestRate) {
                      return 'Taux invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _Label('Date d\'échéance *'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _dueDate == null
                              ? 'Choisir une date et une heure'
                              : () {
                                  final d = _dueDate!;
                                  final t = _dueTime ??
                                      const TimeOfDay(hour: 23, minute: 59);
                                  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
                                      '  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                }(),
                          style: TextStyle(
                            color: _dueDate == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (_dueDate != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _dueDate = null;
                              _dueTime = null;
                            }),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Label('Note (optionnelle)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLength: 150,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Raison du prêt…',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Envoyer la demande'),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}
