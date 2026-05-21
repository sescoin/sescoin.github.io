import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = true;
  Map<String, dynamic>? _selectedUser;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un destinataire.')),
      );
      return;
    }

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final username = _selectedUser!['username'] as String;

    try {
      await ref.read(transferProvider.notifier).transferByUsername(
            toUsername: username,
            amount: amount,
            description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${amount.toStringAsFixed(2)} SC envoyés à @$username',
            ),
            backgroundColor: AppTheme.positive,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider);

    return LoadingOverlay(
      isLoading: state.isLoading,
      message: 'Envoi en cours...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Transférer')),
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
                Text(
                  'Destinataire',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_selectedUser != null) ...[
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                      child: Text(
                        (_selectedUser!['display_name'] as String)[0]
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gold,
                        ),
                      ),
                    ),
                    label: Text(_selectedUser!['display_name'] as String),
                    onDeleted: () => setState(() => _selectedUser = null),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _searchCtrl,
                  onChanged: (q) => setState(() => _searchQuery = q),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
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
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _filteredUsers.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final u = _filteredUsers[i];
                                    final selected =
                                        _selectedUser?['id'] == u['id'];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppTheme.gold
                                            .withValues(alpha: 0.15),
                                        child: Text(
                                          (u['display_name'] as String)[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.gold,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      title: Text(u['display_name'] as String),
                                      subtitle: Text(
                                        '@${u['username']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      trailing: selected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: AppTheme.positive,
                                              size: 18,
                                            )
                                          : null,
                                      onTap: () => setState(() {
                                        _selectedUser = u;
                                        _searchCtrl.text =
                                            u['display_name'] as String;
                                        _searchQuery = '';
                                      }),
                                    );
                                  },
                                ),
                              ),
                            ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Montant',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    suffixText: 'SC',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                    if (n == null || n < AppConstants.minTransferAmount) {
                      return 'Montant minimum : ${AppConstants.minTransferAmount} SC';
                    }
                    if (n > AppConstants.maxTransferAmount) {
                      return 'Montant maximum : ${AppConstants.maxTransferAmount} SC';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Description (optionnelle)',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  textInputAction: TextInputAction.done,
                  maxLength: 100,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Pour quoi ?',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Envoyer'),
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
