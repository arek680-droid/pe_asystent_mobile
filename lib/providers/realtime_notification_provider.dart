import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../services/notification_service.dart';

final realtimeNotificationProvider = Provider<void>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return;

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
          final newRecord = payload.newRecord;
          final title = newRecord['title'] as String? ?? 'Nowe zadanie';
          final assignedTo = newRecord['assigned_to'] as String?;
          final creatorId = newRecord['created_by'] as String?;

          // Ignore if user is the creator
          if (creatorId == user.id) return;

          // Notify only if it is assigned to this user OR is unassigned
          if (assignedTo == null || assignedTo.isEmpty || assignedTo == user.id) {
            notificationService.showNotification(
              id: newRecord['id'].hashCode,
              title: 'Nowe zadanie 📋',
              body: title,
            );
          }
        },
      )
      .subscribe();

  // 2. Listen for new comments
  final commentsChannel = client
      .channel('realtime_comments')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'project_task_comments',
        callback: (payload) async {
          final newRecord = payload.newRecord;
          final comment = newRecord['comment'] as String? ?? '';
          final taskId = newRecord['task_id'] as String?;
          final authorId = newRecord['user_id'] as String?;

          // Ignore if user is the author
          if (authorId == user.id) return;

          if (taskId != null) {
            try {
              final taskData = await client
                  .from('project_tasks')
                  .select('title, assigned_to, created_by')
                  .eq('id', taskId)
                  .maybeSingle();

              if (taskData != null) {
                final taskTitle = taskData['title'] as String? ?? 'Zadanie';
                final assignedTo = taskData['assigned_to'] as String?;
                final createdBy = taskData['created_by'] as String?;

                // Notify only if user is assigned to the task, or created the task,
                // or if the task is unassigned (so everyone is interested).
                if (assignedTo == null ||
                    assignedTo.isEmpty ||
                    assignedTo == user.id ||
                    createdBy == user.id) {
                  notificationService.showNotification(
                    id: newRecord['id'].hashCode,
                    title: 'Nowy komentarz w: $taskTitle 💬',
                    body: comment,
                  );
                }
              }
            } catch (_) {
              // Fail silently on fetch error
            }
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    tasksChannel.unsubscribe();
    commentsChannel.unsubscribe();
  });
});
