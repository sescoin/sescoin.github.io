import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/grouped_report.dart';
import '../models/report.dart';
import '../models/sanction.dart';
import 'service_providers.dart';

/// Journal des sanctions, les plus récentes d'abord.
final sanctionsProvider = StreamProvider<List<Sanction>>((ref) {
  return ref
      .watch(supabaseClientProvider)
      .from('sanctions')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(200)
      .map((rows) => rows.map(Sanction.fromJson).toList());
});

/// Signalements déjà retenus contre un compte : distingue le premier écart
/// de la récidive.
final confirmedReportsProvider =
    FutureProvider.family<int, String>((ref, userId) {
  return ref.read(profileServiceProvider).confirmedReportsCount(userId);
});

/// Signalements regroupés par message, du plus signalé au moins signalé.
///
/// L'agrégation est faite par la base : rapatrier tous les signalements pour
/// les regrouper ici ferait grossir l'échange sans raison.
final groupedReportsProvider =
    FutureProvider<List<GroupedReport>>((ref) async {
  // Se rafraîchit dès qu'un signalement arrive ou change d'état.
  ref.watch(reportsProvider);
  final rows = await ref
      .read(supabaseClientProvider)
      .rpc('admin_grouped_reports') as List;
  return rows
      .map((r) => GroupedReport.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Transcription complète d'un chat, pour l'export en fichier.
final chatTranscriptProvider =
    FutureProvider.family<List<TranscriptLine>, String?>((ref, classId) async {
  final rows = await ref.read(supabaseClientProvider).rpc(
        'admin_chat_transcript',
        params: {'p_class_id': classId},
      ) as List;
  return rows
      .map((r) => TranscriptLine.fromJson(r as Map<String, dynamic>))
      .toList();
});

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

  /// Traite d'un coup tous les signalements portant sur le même message.
  Future<void> setStatusMany(List<String> reportIds, String status) async {
    if (reportIds.isEmpty) return;
    state = const AsyncValue.loading();
    try {
      await _ref.read(supabaseClientProvider).from('reports').update({
        'status': status,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).inFilter('id', reportIds);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

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
