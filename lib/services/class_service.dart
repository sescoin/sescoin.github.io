import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_room.dart';
import '../models/profile.dart';

class ClassService {
  ClassService(this._client);

  final SupabaseClient _client;

  Future<List<ClassRoom>> getClasses() async {
    final response = await _client.rpc('get_classes');
    return (response as List)
        .map((e) => ClassRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createClass(String name) async {
    final response = await _client.rpc('create_class', params: {'p_name': name});
    return response as String;
  }

  Future<void> renameClass(String classId, String name) async {
    await _client.rpc('rename_class', params: {
      'p_class_id': classId,
      'p_name': name,
    });
  }

  Future<void> deleteClass(String classId) async {
    await _client.rpc('delete_class', params: {'p_class_id': classId});
  }

  Future<void> setUserClass(String userId, String? classId) async {
    await _client.rpc('set_user_class', params: {
      'p_user_id': userId,
      'p_class_id': classId,
    });
  }

  Future<List<Profile>> getClassMembers(String classId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('class_id', classId)
        .order('display_name', ascending: true);
    return (response as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Profile>> getUsersWithoutClass() async {
    final response = await _client
        .from('profiles')
        .select()
        .isFilter('class_id', null)
        .neq('role', 'admin')
        .order('display_name', ascending: true);
    return (response as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
