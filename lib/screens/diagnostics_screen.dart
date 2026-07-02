import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../providers/update_provider.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    LogService().setListener(_onLogAdded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    LogService().clearListener();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogAdded() {
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = LogService().logs;
    final isInitialized = NotificationService().isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Diagnostyka Realtime',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              LogService().clearLogs();
            },
            tooltip: 'Wyczyść logi',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info panel (Notifications status)
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status Powiadomień:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isInitialized ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isInitialized ? 'Aktywne' : 'Nieaktywne',
                              style: TextStyle(
                                color: isInitialized ? Colors.green.shade800 : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          LogService().addLog('[Diagnostics] Wywołano testowe powiadomienie...');
                          await NotificationService().showNotification(
                            id: 9999,
                            title: 'Powiadomienie testowe 🚀',
                            body: 'Wszystko działa jak należy!',
                          );
                        },
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Wyślij powiadomienie testowe'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // App Update status card
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final updateState = ref.watch(updateProvider);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Aktualizacje (GitHub):',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: updateState.hasUpdate ? Colors.green.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  updateState.hasUpdate ? 'Dostępna aktualizacja' : 'Najnowsza wersja',
                                  style: TextStyle(
                                    color: updateState.hasUpdate ? Colors.green.shade800 : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Obecna wersja: ${updateState.currentVersion}'),
                          Text('Wersja na GitHubie: ${updateState.latestVersion}'),
                          if (updateState.error != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Błąd: ${updateState.error}',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: updateState.isLoading
                                      ? null
                                      : () {
                                          ref.read(updateProvider.notifier).checkForUpdates();
                                        },
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Sprawdź'),
                                ),
                              ),
                              if (updateState.hasUpdate) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      ref.read(updateProvider.notifier).launchUpdateUrl();
                                    },
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text('Pobierz APK'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logi Systemowe (na żywo):',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Brak logów. Wykonaj akcję, aby zobaczyć wpisy.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final isError = log.contains('ERROR');
                            final isWarning = log.contains('WARNING');
                            final isSuccess = log.contains('successfully') || log.contains('SUBSCRIBED');

                            Color logColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
                            if (isError) {
                              logColor = Colors.red;
                            } else if (isWarning) {
                              logColor = Colors.orange.shade800;
                            } else if (isSuccess) {
                              logColor = Colors.green.shade700;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                log,
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  color: logColor,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
