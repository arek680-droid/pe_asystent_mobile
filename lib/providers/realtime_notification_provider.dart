import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';

final realtimeNotificationProvider = Provider<void>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) {
    LogService().addLog('[RealtimeNotifications] No user logged in, skipping.');
    return;
  }

  LogService().addLog('[RealtimeNotifications] Setting up for user: ${user.id} (${user.email})');

  final notificationService = NotificationService();
  notificationService.initialize();

  final client = Supabase.instance.client;

  // 1. Listen for new tasks
  final tasksChannel = client
      .channel('realtime_tasks')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'project_tasks',
        callback: (payload) {
          LogService().addLog('[RealtimeNotifications] NEW TASK event received!');
          LogService().addLog('[RealtimeNotifications] Payload: ${payload.newRecord}');

          final newRecord = payload.newRecord;
          final title = newRecord['title'] as String? ?? 'Nowe zadanie';
          final creatorId = newRecord['created_by'] as String?;

          // Ignore if user is the creator
          if (creatorId == user.id) {
            LogService().addLog('[RealtimeNotifications] Skipping task notification: User is the creator');
            return;
          }

          LogService().addLog('[RealtimeNotifications] Showing task notification: "$title"');
          notificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: 'Nowe zadanie 📋',
            body: title,
          );
        },
      )
      .subscribe((status, [error]) {
        LogService().addLog('[RealtimeNotifications] Tasks channel status: $status${error != null ? ", error: $error" : ""}');
      });

  // 2. Listen for new comments
  final commentsChannel = client
      .channel('realtime_comments')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'project_task_comments',
        callback: (payload) async {
          LogService().addLog('[RealtimeNotifications] NEW COMMENT event received!');
          LogService().addLog('[RealtimeNotifications] Payload: ${payload.newRecord}');

          final newRecord = payload.newRecord;
          final comment = newRecord['comment'] as String? ?? '';
          final taskId = newRecord['task_id'] as String?;
          final authorId = newRecord['user_id'] as String?;

          // Ignore if user is the author
          if (authorId == user.id) {
            LogService().addLog('[RealtimeNotifications] Skipping comment notification: User is the author');
            return;
          }

          if (taskId != null) {
            try {
              final taskData = await client
                  .from('project_tasks')
                  .select('title')
                  .eq('id', taskId)
                  .maybeSingle();

              LogService().addLog('[RealtimeNotifications] Task data for comment: $taskData');

              final taskTitle = taskData != null ? (taskData['title'] as String?) : null;
              final displayTitle = taskTitle != null ? 'w: $taskTitle' : '';

              LogService().addLog('[RealtimeNotifications] Showing comment notification: "$comment"');
              notificationService.showNotification(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                title: 'Nowy komentarz $displayTitle 💬',
                body: comment,
              );
            } catch (e) {
              LogService().addLog('[RealtimeNotifications] ERROR fetching task for comment: $e');
            }
          }
        },
      )
      .subscribe((status, [error]) {
        LogService().addLog('[RealtimeNotifications] Comments channel status: $status${error != null ? ", error: $error" : ""}');
      });

  ref.onDispose(() {
    LogService().addLog('[RealtimeNotifications] Disposing channels (unsubscribing)...');
    tasksChannel.unsubscribe();
    commentsChannel.unsubscribe();
  });
});
