import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateState {
  final bool isLoading;
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String? error;

  UpdateState({
    this.isLoading = false,
    this.hasUpdate = false,
    this.currentVersion = '',
    this.latestVersion = '',
    this.apkUrl = '',
    this.error,
  });

  UpdateState copyWith({
    bool? isLoading,
    bool? hasUpdate,
    String? currentVersion,
    String? latestVersion,
    String? apkUrl,
    String? error,
  }) {
    return UpdateState(
      isLoading: isLoading ?? this.isLoading,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      apkUrl: apkUrl ?? this.apkUrl,
      error: error,
    );
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(UpdateState()) {
    checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Get current app version from the device
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      // 2. Fetch latest version info from Supabase app_config table
      final response = await Supabase.instance.client
          .from('app_config')
          .select('key, value');

      final List<dynamic> data = response as List<dynamic>;
      String latestVersion = '1.0.0';
      String apkUrl = '';

      for (var item in data) {
        final map = item as Map<String, dynamic>;
        if (map['key'] == 'latest_version') {
          latestVersion = map['value'].toString();
        } else if (map['key'] == 'apk_url') {
          apkUrl = map['value'].toString();
        }
      }

      // 3. Compare versions
      final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

      state = UpdateState(
        isLoading: false,
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        apkUrl: apkUrl,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Simple semver comparison helper
  bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (_) {
      // Fallback to simple string comparison if parsing fails
      return current != latest;
    }
    return false;
  }

  Future<void> launchUpdateUrl() async {
    if (state.apkUrl.isEmpty) return;
    final url = Uri.parse(state.apkUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Opens in external browser
      );
    } else {
      throw 'Could not launch $url';
    }
  }
}
