import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report.dart';
import 'service_providers.dart';

/// Signalements en attente puis traités, les plus récents d'abord.
///
/// La lecture est réservée à l'administrateur par les policies : un élève
/// interrogeant cette table n'obtiendrait qu'une liste vide.
final reportsProvider = StreamProvider<List<Report>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client
      .from('reports')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Report.fromJson).toList());
});

/// Nombre de signalements non traités, pour la pastille du menu admin.
final pendingReportsCountProvider = Provider<int>((ref) {
  return ref.watch(reportsProvider).valueOrNull?.where((r) => r.isPending).length ??
      0;
});

class ReportActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ReportActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Marque un signalement comme traité ou écarté.
  Future<void> setStatus(String reportId, String status) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(supabaseClientProvider).from('reports').update({
        'status': status,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', reportId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> delete(String reportId) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(supabaseClientProvider)
          .from('reports')
          .delete()
          .eq('id', reportId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }
}

final reportActionsProvider =
    StateNotifierProvider<ReportActionsNotifier, AsyncValue<void>>(
  (ref) => ReportActionsNotifier(ref),
);
