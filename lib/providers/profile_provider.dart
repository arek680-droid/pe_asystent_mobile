import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

final profileProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      final displayName = response['display_name']?.toString();
      
      if (displayName != null && displayName.trim().isNotEmpty) {
        return displayName;
      }
    }
  } catch (_) {
    // Fallback to email prefix on any error
  }

  // Default fallback
  return user.email?.split('@')[0] ?? 'Użytkownik';
});
