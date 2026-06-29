import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
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
      // 1. Pobierz obecny numer budowania (buildNumber) z urządzenia
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersionName = packageInfo.version;

      // 2. Pobierz informacje o najnowszym wydaniu z API GitHuba
      final url = Uri.parse('https://api.github.com/repos/arek680-droid/pe_asystent_mobile/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final tagName = data['tag_name'] as String? ?? 'v0'; // np. "v5"
        
        // Wyciągamy numer z tagu (np. "v5" -> 5)
        final latestBuild = int.tryParse(tagName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        // Stały link do pobrania najnowszego APK
        final apkUrl = 'https://github.com/arek680-droid/pe_asystent_mobile/releases/latest/download/app-debug.apk';

        // 3. Porównaj numery budowania
        final hasUpdate = latestBuild > currentBuild;

        state = UpdateState(
          isLoading: false,
          hasUpdate: hasUpdate,
          currentVersion: '$currentVersionName (Wersja $currentBuild)',
          latestVersion: 'Wersja $latestBuild',
          apkUrl: apkUrl,
        );
      } else {
        // Czasami przy pierwszym uruchomieniu nie ma jeszcze żadnego release na GitHubie
        state = UpdateState(
          isLoading: false,
          hasUpdate: false,
          currentVersion: '$currentVersionName (Wersja $currentBuild)',
          latestVersion: 'Brak wydań na GitHub',
          apkUrl: '',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> launchUpdateUrl() async {
    if (state.apkUrl.isEmpty) return;
    final url = Uri.parse(state.apkUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Otwiera w zewnętrznej przeglądarce
      );
    } else {
      throw 'Nie można otworzyć linku: $url';
    }
  }
}
