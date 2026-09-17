import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/app_dialog.dart';
import '../../common/app_feedback.dart';
import '../../common/ban_guard.dart';
import '../../common/date_utils.dart';
import '../../common/loading_overlay.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/loan_provider.dart';

/// Façon de renseigner l'échéance d'un prêt.
enum _DueMode {
  /// Date et heure choisies au calendrier.
  date,

  /// Durée à compter de l'envoi, en jours, heures et minutes.
  duration,
}

class LoanCreateScreen extends ConsumerStatefulWidget {
  const LoanCreateScreen({
    super.key,
    this.isChatMode = false,
    this.chatClassId,
  });

  final bool isChatMode;

  /// null = demande publiée dans les Annonces ; non-null = chat de classe.
  final String? chatClassId;

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

  /// Deux façons de fixer l'échéance : une date précise, ou une durée à
  /// compter de l'envoi. Voir [_DueMode].
  _DueMode _dueMode = _DueMode.date;
  final _daysController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  final List<Map<String, dynamic>> _selectedLenders = [];
  bool _loadingUsers = false;
  String _searchQuery = '';
  bool _isSubmitting = false;

  bool get _isChatMode => widget.isChatMode;

  @override
  void initState() {
    super.initState();
    if (!_isChatMode) _loadUsers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    _daysController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
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

      if (!mounted) return;
      setState(() {
        _allUsers = List<Map<String, dynamic>>.from(data as List);
        _loadingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _allUsers;
    return _allUsers.where((user) {
      final username = (user['username'] as String).toLowerCase();
      final name = (user['display_name'] as String).toLowerCase();
      return username.contains(query) || name.contains(query);
    }).toList();
  }

  void _addLender(Map<String, dynamic> user) {
    if (_selectedLenders.any((lender) => lender['id'] == user['id'])) return;
    setState(() {
      _selectedLenders.add(user);
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _removeLender(String id) {
    setState(
        () => _selectedLenders.removeWhere((lender) => lender['id'] == id));
  }

  /// Durée saisie, ou `null` si les trois champs sont vides ou nuls.
  Duration? _typedDuration() {
    final d = int.tryParse(_daysController.text.trim()) ?? 0;
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    if (d <= 0 && h <= 0 && m <= 0) return null;
    return Duration(days: d, hours: h, minutes: m);
  }

  /// Échéance effective selon le mode retenu.
  ///
  /// En mode durée, elle est calculée au moment de la validation : saisir
  /// « 2 jours » doit compter à partir de l'envoi, pas de l'ouverture de
  /// l'écran.
  DateTime? _resolveDue() {
    if (_dueMode == _DueMode.duration) {
      final duration = _typedDuration();
      return duration == null ? null : DateTime.now().add(duration);
    }
    if (_dueDate == null) return null;
    final t = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      t.hour,
      t.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(Duration(days: AppConstants.maxLoanDurationDays)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final isToday = pickedDate.year == now.year &&
        pickedDate.month == now.month &&
        pickedDate.day == now.day;

    final minTime = now.add(const Duration(minutes: 5));
    final defaultTime = isToday
        ? TimeOfDay(hour: minTime.hour, minute: minTime.minute)
        : const TimeOfDay(hour: 23, minute: 59);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: (_dueTime != null && !isToday) ? _dueTime! : defaultTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (!mounted) return;

    TimeOfDay finalTime = pickedTime ?? defaultTime;

    if (isToday) {
      final selected = DateTime(
          now.year, now.month, now.day, finalTime.hour, finalTime.minute);
      if (selected.isBefore(minTime)) {
        finalTime = TimeOfDay(hour: minTime.hour, minute: minTime.minute);
      }
    }

    setState(() {
      _dueDate = pickedDate;
      _dueTime = finalTime;
    });
  }

  /// « 2 jours 3 h 15 min », en n'affichant que les composantes utiles.
  static String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[
      if (days > 0) days == 1 ? 'un jour' : '$days jours',
      if (hours > 0) '$hours h',
      if (minutes > 0) '$minutes min',
    ];
    return parts.isEmpty ? '0 min' : parts.join(' ');
  }

  String _formatDue() {
    final d = _dueDate!;
    final t = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return formatLoanDueDateLabel(
      DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  Future<void> _submit() async {
    if (!ensureNotBanned(context, ref)) return;
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(currentProfileProvider).value;
    if (profile != null && profile.balance < 0) {
      AppFeedback.error(
        context,
        'Impossible de demander un prêt avec un solde négatif.',
      );
      return;
    }

    if (!_isChatMode && _selectedLenders.isEmpty) {
      AppFeedback.warning(context, 'Au moins un prêteur est requis.');
      return;
    }

    // En mode durée, aucune échéance n'est fixée : le décompte ne démarre
    // qu'à l'acceptation de la demande.
    final isDurationMode = _dueMode == _DueMode.duration;
    final duration = isDurationMode ? _typedDuration() : null;
    final combinedDue = isDurationMode ? null : _resolveDue();
    final now = DateTime.now();

    if (isDurationMode) {
      if (duration == null) {
        AppFeedback.warning(context, 'Une durée est requise.');
        return;
      }
      if (duration.inMinutes < 5) {
        AppFeedback.warning(
          context,
          'La durée doit valoir au moins 5 minutes.',
        );
        return;
      }
      if (duration.inMinutes > AppConstants.maxLoanDurationDays * 1440) {
        AppFeedback.warning(
          context,
          'La durée ne peut pas dépasser '
          '${AppConstants.maxLoanDurationDays} jours.',
        );
        return;
      }
    } else {
      if (combinedDue == null) {
        AppFeedback.warning(context, 'Une date d\'échéance est requise.');
        return;
      }
      if (combinedDue.isBefore(now.add(const Duration(minutes: 1)))) {
        AppFeedback.warning(context, 'L\'échéance doit être dans le futur.');
        return;
      }
      if (combinedDue.isAfter(
        now.add(Duration(days: AppConstants.maxLoanDurationDays)),
      )) {
        AppFeedback.warning(
          context,
          'L\'échéance ne peut pas dépasser '
          '${AppConstants.maxLoanDurationDays} jours.',
        );
        return;
      }
    }

    final principal =
        double.parse(_amountController.text.trim().replaceAll(',', '.'));
    final interestRate =
        double.parse(_interestController.text.trim().replaceAll(',', '.'));

    final totalDue = principal * (1 + interestRate / 100);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.handshake_rounded,
        title: 'Confirmer la demande',
        subtitle: _isChatMode
            ? (widget.chatClassId == null
                ? 'Publiée dans les annonces'
                : 'Publiée dans le chat de la classe')
            : '${_selectedLenders.length > 1 ? 'Prêteurs' : 'Prêteur'} : '
                '${_selectedLenders.map((l) => l['display_name']).join(', ')}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RecapRow(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Montant',
              value: '${principal.toStringAsFixed(2)} SC',
              emphasize: true,
            ),
            _RecapRow(
              icon: Icons.percent_rounded,
              label: 'Intérêt',
              value: '${interestRate.toStringAsFixed(1)} %',
            ),
            _RecapRow(
              icon: Icons.payments_rounded,
              label: 'À rembourser',
              value: '${totalDue.toStringAsFixed(2)} SC',
              emphasize: true,
            ),
            if (isDurationMode)
              _RecapRow(
                icon: Icons.timer_outlined,
                label: 'Durée',
                value: _formatDuration(duration!),
              )
            else
              _RecapRow(
                icon: Icons.event_rounded,
                label: 'Échéance',
                value: formatLoanDueDateLabel(combinedDue!),
              ),
            if (isDurationMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: context.accent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Aucune date fixée : le décompte démarre au moment '
                        'où la demande est acceptée.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_rounded, size: 17),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    // ── Mode chat : envoie dans le chat global ────────────────────────────────
    if (_isChatMode) {
      setState(() => _isSubmitting = true);
      try {
        final result =
            await ref.read(chatActionProvider.notifier).sendLoanRequestChat(
                  principal,
                  interestRate: interestRate > 0 ? interestRate : null,
                  dueDate: combinedDue,
                  note: note,
                  classId: widget.chatClassId,
                  // En mode durée, on transmet la durée et non une date : le
                  // délai doit courir à partir de l'acceptation.
                  durationMinutes: duration?.inMinutes,
                );
        if (!mounted) return;
        if (result == null) {
          final errorMessage = ref.read(chatActionProvider).error?.trim();
          AppFeedback.error(
            context,
            errorMessage == null || errorMessage.isEmpty
                ? 'L\'envoi a échoué.'
                : errorMessage,
          );
        } else {
          AppFeedback.success(context, 'Demande de prêt publiée.');
          context.pop();
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    // ── Mode normal : envoie à des prêteurs ciblés ────────────────────────────
    var sent = 0;
    final errors = <String>[];

    for (final lender in _selectedLenders) {
      try {
        await ref.read(loanActionProvider.notifier).requestLoan(
              lenderUsername: lender['username'] as String,
              principal: principal,
              interestRate: interestRate,
              dueDate: combinedDue,
              note: note,
              // Même règle qu'en mode chat : l'échéance part de l'acceptation.
              durationMinutes: duration?.inMinutes,
            );
        sent++;
      } catch (error) {
        final reason = error.toString().replaceFirst('Exception: ', '');
        errors.add(
          _selectedLenders.length == 1
              ? reason
              : '${lender['display_name']} : $reason',
        );
      }
    }

    if (!mounted) return;

    if (errors.isNotEmpty) {
      final message = sent > 0
          ? '$sent envoyée(s)\n${errors.join('\n')}'
          : errors.join('\n');
      if (errors.length == _selectedLenders.length) {
        AppFeedback.error(context, message);
      } else {
        AppFeedback.warning(context, message);
      }
      return;
    }

    AppFeedback.success(
      context,
      '$sent demande(s) de prêt envoyée(s) avec succès !',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loanState = ref.watch(loanActionProvider);
    final isLoading = _isChatMode ? _isSubmitting : loanState.isLoading;

    return LoadingOverlay(
      isLoading: isLoading,
      message: 'Envoi de la demande...',
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
                // ── Sélection prêteur (mode normal uniquement) ─────────────────
                if (!_isChatMode) ...[
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
                                    context.accent.withValues(alpha: 0.2),
                                child: Text(
                                  (lender['display_name'] as String)[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.accent,
                                  ),
                                ),
                              ),
                              label: Text(lender['display_name'] as String),
                              onDeleted: () =>
                                  _removeLender(lender['id'] as String),
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
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
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
                                      final alreadySelected =
                                          _selectedLenders.any(
                                        (lender) => lender['id'] == user['id'],
                                      );
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: context.accent
                                              .withValues(alpha: 0.15),
                                          child: Text(
                                            (user['display_name'] as String)[0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: context.accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                            user['display_name'] as String),
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
                                        onTap: alreadySelected
                                            ? null
                                            : () => _addLender(user),
                                      );
                                    },
                                  ),
                                ),
                              ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Montant ────────────────────────────────────────────────────
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
                    if (amount == null ||
                        amount < AppConstants.minTransferAmount) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Taux d'intérêt ─────────────────────────────────────────────
                _Label('Taux d\'intérêt'),
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

                // ── Échéance ───────────────────────────────────────────────────
                _Label('Échéance *'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_DueMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      textStyle: TextStyle(
                        fontFamily: context.fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: _DueMode.date,
                        icon: Icon(Icons.event_rounded, size: 16),
                        label: Text('Date'),
                      ),
                      ButtonSegment(
                        value: _DueMode.duration,
                        icon: Icon(Icons.timer_outlined, size: 16),
                        label: Text('Durée'),
                      ),
                    ],
                    selected: {_dueMode},
                    onSelectionChanged: (s) =>
                        setState(() => _dueMode = s.first),
                  ),
                ),
                const SizedBox(height: 10),
                if (_dueMode == _DueMode.date)
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
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
                                : _formatDue(),
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
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _DurationField(
                          controller: _daysController,
                          label: 'Jours',
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DurationField(
                          controller: _hoursController,
                          label: 'Heures',
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DurationField(
                          controller: _minutesController,
                          label: 'Minutes',
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // ── Note ───────────────────────────────────────────────────────
                _Label('Note (optionnelle)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLength: 150,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Motif du prêt…',
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _submit,
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

/// Champ numérique compact pour une composante de la durée.
/// Ligne du récapitulatif de confirmation : icône, libellé, valeur.
class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Met la valeur en avant (montants).
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.accent),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13.5,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? context.accent : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
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
