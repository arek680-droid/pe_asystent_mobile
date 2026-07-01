import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../services/notification_service.dart';

final realtimeNotificationProvider = Provider<void>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) {
    debugPrint('[RealtimeNotifications] No user logged in, skipping.');
    return;
  }

  debugPrint('[RealtimeNotifications] Setting up for user: ${user.id}');

  final notificationService = NotificationService();
  // Fire-and-forget initialization — showNotification will also auto-init if needed.
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
          debugPrint('[RealtimeNotifications] NEW TASK event received!');
          debugPrint('[RealtimeNotifications] Payload: ${payload.newRecord}');

          final newRecord = payload.newRecord;
          final title = newRecord['title'] as String? ?? 'Nowe zadanie';
          final assignedTo = newRecord['assigned_to'] as String?;
          final creatorId = newRecord['created_by'] as String?;

          debugPrint('[RealtimeNotifications] Task creator: $creatorId, assigned_to: $assignedTo, current user: ${user.id}');

          // Ignore if user is the creator
          if (creatorId == user.id) {
            debugPrint('[RealtimeNotifications] Skipping — user is the creator.');
            return;
          }

          // Notify only if assigned to this user OR unassigned
          if (assignedTo == null || assignedTo.isEmpty || assignedTo == user.id) {
            debugPrint('[RealtimeNotifications] Showing task notification...');
            notificationService.showNotification(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              title: 'Nowe zadanie 📋',
              body: title,
            );
          } else {
            debugPrint('[RealtimeNotifications] Skipping — assigned to someone else: $assignedTo');
          }
        },
      )
      .subscribe((status, [error]) {
        debugPrint('[RealtimeNotifications] Tasks channel status: $status, error: $error');
      });

  // 2. Listen for new comments
  final commentsChannel = client
      .channel('realtime_comments')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'project_task_comments',
        callback: (payload) async {
          debugPrint('[RealtimeNotifications] NEW COMMENT event received!');
          debugPrint('[RealtimeNotifications] Payload: ${payload.newRecord}');

          final newRecord = payload.newRecord;
          final comment = newRecord['comment'] as String? ?? '';
          final taskId = newRecord['task_id'] as String?;
          final authorId = newRecord['user_id'] as String?;

          debugPrint('[RealtimeNotifications] Comment author: $authorId, current user: ${user.id}');

          // Ignore if user is the author
          if (authorId == user.id) {
            debugPrint('[RealtimeNotifications] Skipping — user is the comment author.');
            return;
          }

          if (taskId != null) {
            try {
              final taskData = await client
                  .from('project_tasks')
                  .select('title, assigned_to, created_by')
                  .eq('id', taskId)
                  .maybeSingle();

              debugPrint('[RealtimeNotifications] Task data for comment: $taskData');

              if (taskData != null) {
                final taskTitle = taskData['title'] as String? ?? 'Zadanie';
                final assignedTo = taskData['assigned_to'] as String?;
                final createdBy = taskData['created_by'] as String?;

                if (assignedTo == null ||
                    assignedTo.isEmpty ||
                    assignedTo == user.id ||
                    createdBy == user.id) {
                  debugPrint('[RealtimeNotifications] Showing comment notification...');
                  notificationService.showNotification(
                    id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                    title: 'Nowy komentarz w: $taskTitle 💬',
                    body: comment,
                  );
                } else {
                  debugPrint('[RealtimeNotifications] Skipping — not relevant to user.');
                }
              }
            } catch (e) {
              debugPrint('[RealtimeNotifications] ERROR fetching task for comment: $e');
            }
          }
        },
      )
      .subscribe((status, [error]) {
        debugPrint('[RealtimeNotifications] Comments channel status: $status, error: $error');
      });

  ref.onDispose(() {
    debugPrint('[RealtimeNotifications] Disposing channels...');
    tasksChannel.unsubscribe();
    commentsChannel.unsubscribe();
  });
});
