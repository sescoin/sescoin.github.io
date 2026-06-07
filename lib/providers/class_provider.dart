import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_room.dart';
import '../models/profile.dart';
import 'service_providers.dart';

final classListProvider = FutureProvider<List<ClassRoom>>((ref) {
  return ref.watch(classServiceProvider).getClasses();
});

final classMembersProvider =
    FutureProvider.family<List<Profile>, String>((ref, classId) {
  return ref.watch(classServiceProvider).getClassMembers(classId);
});

final usersWithoutClassProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(classServiceProvider).getUsersWithoutClass();
});

class ClassState {
  const ClassState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  ClassState copyWith({bool? isLoading, String? error, bool clearError = false}) {
    return ClassState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final classActionProvider =
    StateNotifierProvider<ClassActionNotifier, ClassState>((ref) {
  return ClassActionNotifier(ref);
});

class ClassActionNotifier extends StateNotifier<ClassState> {
  ClassActionNotifier(this._ref) : super(const ClassState());

  final Ref _ref;

  Future<String?> createClass(String name) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final id = await _ref.read(classServiceProvider).createClass(name);
      _ref.invalidate(classListProvider);
      state = state.copyWith(isLoading: false);
      return id;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  Future<bool> renameClass(String classId, String name) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(classServiceProvider).renameClass(classId, name);
      _ref.invalidate(classListProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> deleteClass(String classId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(classServiceProvider).deleteClass(classId);
      _ref.invalidate(classListProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> setUserClass(String userId, String? classId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(classServiceProvider).setUserClass(userId, classId);
      _ref.invalidate(classListProvider);
      _ref.invalidate(classMembersProvider);
      _ref.invalidate(usersWithoutClassProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
