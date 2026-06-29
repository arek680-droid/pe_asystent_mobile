import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import 'auth_provider.dart';

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('projects')
      .select('id, name, description')
      .order('name', ascending: true);

  final List<dynamic> data = response as List<dynamic>;
  return data.map((json) => Project.fromJson(json as Map<String, dynamic>)).toList();
});
