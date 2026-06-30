import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

// Provider to check if the logged in user is an administrator
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return false;
  try {
    final response = await Supabase.instance.client
        .from('user_profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    
    if (response != null) {
      return response['role']?.toString() == 'admin';
    }
  } catch (_) {
    // Fallback to false on error
  }
  return false;
});

// Provider to manage global gamification visibility setting in the app_settings table
final gamificationSettingsProvider = StateNotifierProvider<GamificationSettingsNotifier, AsyncValue<bool>>((ref) {
  return GamificationSettingsNotifier();
});

class GamificationSettingsNotifier extends StateNotifier<AsyncValue<bool>> {
  GamificationSettingsNotifier() : super(const AsyncValue.loading()) {
    fetchSettings();
  }

  Future<void> fetchSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'show_gamification')
          .maybeSingle();
      
      if (response != null && response['value'] != null) {
        // Since value is JSONB, cast it safely
        final dynamic val = response['value'];
        if (val is bool) {
          state = AsyncValue.data(val);
        } else if (val is String) {
          state = AsyncValue.data(val.toLowerCase() == 'true');
        } else {
          state = const AsyncValue.data(true);
        }
      } else {
        // Default to true if the setting does not exist yet
        state = const AsyncValue.data(true);
      }
    } catch (_) {
      // Fallback to true on error
      state = const AsyncValue.data(true);
    }
  }

  Future<void> updateSetting(bool value) async {
    // Optimistic update
    final previousState = state;
    state = AsyncValue.data(value);
    
    try {
      await Supabase.instance.client.from('app_settings').upsert({
        'key': 'show_gamification',
        'value': value,
      });
    } catch (e, stack) {
      // Revert on error
      state = previousState;
      state = AsyncValue.error(e, stack);
    }
  }
}
