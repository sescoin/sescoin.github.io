import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../common/loading_overlay.dart';

class LoanCreateScreen extends ConsumerStatefulWidget {
  const LoanCreateScreen({super.key});

  @override
  ConsumerState<LoanCreateScreen> createState() => _LoanCreateScreenState();
}

class _LoanCreateScreenState extends ConsumerState<LoanCreateScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _searchCtrl = TextEditingController();

  DateTime? _dueDate;

  // Tous les utilisateurs (chargés une fois)
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = true;

  // Prêteurs sélectionnés
  final List<Map<String, dynamic>> _selectedLenders = [];

  // Filtre recherche
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
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
      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(data as List);
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      final username = (u['username'] as String).toLowerCase();
      final name = (u['display_name'] as String).toLowerCase();
      return username.contains(q) || name.contains(q);
    }).toList();
  }

  void _addLender(Map<String, dynamic> user) {
    if (_selectedLenders.any((l) => l['id'] == user['id'])) return;
    setState(() {
      _selectedLenders.add(user);
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  void _removeLender(String id) {
    setState(() => _selectedLenders.removeWhere((l) => l['id'] == id));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate:
          DateTime.now().add(Duration(days: AppConstants.minLoanDurationDays)),
      lastDate:
          DateTime.now().add(Duration(days: AppConstants.maxLoanDurationDays)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLenders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un prêteur')),
      );
      return;
    }

    final principal =
        double.parse(_amountCtrl.text.replaceAll(',', '.'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
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
            if (_dueDate != null)
              Text(
                  'Échéance : ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int sent = 0;
    final errors = <String>[];

    for (final lender in _selectedLenders) {
      try {
        await ref.read(loanActionProvider.notifier).requestLoan(
              lenderUsername: lender['username'] as String,
              principal: principal,
              interestRate: 0,
              dueDate: _dueDate,
              note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
            );
        sent++;
      } catch (e) {
        errors.add('${lender['display_name']} : $e');
      }
    }

    if (!mounted) return;

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sent envoyée(s), ${errors.length} échec(s)'),
          backgroundColor: errors.length == _selectedLenders.length
              ? Colors.red
              : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$sent demande(s) de prêt envoyée(s) avec succès !'),
          backgroundColor: AppTheme.positive,
        ),
      );
      context.pop();
    }
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
                // ── Sélection des prêteurs ───────────────────────────────
                _Label('Prêteur(s)'),
                const SizedBox(height: 8),

                // Chips des prêteurs sélectionnés
                if (_selectedLenders.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedLenders
                        .map(
                          (l) => Chip(
                            avatar: CircleAvatar(
                              backgroundColor:
                                  AppTheme.gold.withValues(alpha: 0.2),
                              child: Text(
                                (l['display_name'] as String)[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.gold),
                              ),
                            ),
                            label: Text(l['display_name'] as String),
                            onDeleted: () =>
                                _removeLender(l['id'] as String),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Champ de recherche
                TextField(
                  controller: _searchCtrl,
                  onChanged: (q) => setState(() => _searchQuery = q),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),

                // Liste filtrée
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
                              constraints:
                                  const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .dividerColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredUsers.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final u = _filteredUsers[i];
                                    final already =
                                        _selectedLenders.any(
                                            (l) => l['id'] == u['id']);
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppTheme.gold
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          (u['display_name']
                                                  as String)[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: AppTheme.gold,
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                      ),
                                      title:
                                          Text(u['display_name'] as String),
                                      subtitle: Text(
                                          '@${u['username']}',
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      trailing: already
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: AppTheme.positive,
                                              size: 18)
                                          : null,
                                      onTap: already
                                          ? null
                                          : () => _addLender(u),
                                    );
                                  },
                                ),
                              ),
                            ),
                ],
                const SizedBox(height: 20),

                // ── Montant ──────────────────────────────────────────────
                _Label('Montant emprunté'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    suffixText: 'SC',
                  ),
                  validator: (v) {
                    final n =
                        double.tryParse(v?.replaceAll(',', '.') ?? '');
                    if (n == null ||
                        n < AppConstants.minTransferAmount) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Date d'échéance ──────────────────────────────────────
                _Label('Date d\'échéance (optionnelle)'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .inputDecorationTheme
                          .fillColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _dueDate == null
                              ? 'Aucune date'
                              : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                          style: TextStyle(
                            color: _dueDate == null
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (_dueDate != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _dueDate = null),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Note ─────────────────────────────────────────────────
                _Label('Note (optionnelle)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
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

// ignore: non_constant_identifier_names
Widget _Label(String text) => Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
