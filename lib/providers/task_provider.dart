import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_task.dart';
import 'auth_provider.dart';
import 'user_stats_provider.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, AsyncValue<List<ProjectTask>>>((ref) {
  return TasksNotifier(ref);
});

class TasksNotifier extends StateNotifier<AsyncValue<List<ProjectTask>>> {
  final Ref _ref;

  TasksNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Re-fetch tasks whenever the auth state changes
    _ref.listen(authProvider, (previous, next) {
      if (next != null) {
        fetchTasks();
      } else {
        state = const AsyncValue.data([]);
      }
    });

    // Initial fetch if user is already logged in
    if (_ref.read(authProvider) != null) {
      fetchTasks();
    }
  }

  Future<void> fetchTasks() async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authProvider);
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Fetch tasks from Supabase project_tasks table
      final response = await Supabase.instance.client
          .from('project_tasks')
          .select()
          .order('created_at', ascending: false);

      // Fetch attachments to check which tasks have images
      final attachmentsResponse = await Supabase.instance.client
          .from('project_task_attachments')
          .select('task_id');
      final List<dynamic> attachmentsData = attachmentsResponse as List<dynamic>;
      final tasksWithAttachments = attachmentsData.map((row) => row['task_id'].toString()).toSet();

      final List<dynamic> data = response as List<dynamic>;
      final tasks = data.map((json) {
        final task = ProjectTask.fromJson(json as Map<String, dynamic>);
        final hasImage = tasksWithAttachments.contains(task.id);
        return task.copyWith(hasImage: hasImage);
      }).toList();
      
      state = AsyncValue.data(tasks);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> updateTaskStatus(ProjectTask task, String newStatus, {double? actualHours, DateTime? completedAt}) async {
    try {
      final finalCompletedAt = newStatus == 'completed' 
          ? (completedAt ?? DateTime.now()) 
          : null;
      
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'completed_at': finalCompletedAt?.toIso8601String(),
      };
      
      if (newStatus == 'completed' && actualHours != null) {
        updateData['actual_hours'] = actualHours;
      }
      
      // Update status in Supabase
      await Supabase.instance.client
          .from('project_tasks')
          .update(updateData)
          .eq('id', task.id);

      // Insert system comment for status change (except for on_hold, which is handled in UI with user reason)
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null && newStatus != 'on_hold') {
        String statusLabel = '';
        switch (newStatus) {
          case 'todo': statusLabel = 'Do zrobienia'; break;
          case 'in_progress': statusLabel = 'W trakcie'; break;
          case 'to_accept': statusLabel = 'Do akceptacji'; break;
          case 'completed': statusLabel = 'Zakończone'; break;
        }

        String commentText = '[STATUS] Zmiana statusu na: $statusLabel';
        if (newStatus == 'completed' && actualHours != null) {
          final h = actualHours.toInt();
          final m = ((actualHours - h) * 60).round();
          commentText += ' (Czas pracy: ${h}h ${m}m)';
        }

        try {
          await Supabase.instance.client.from('project_task_comments').insert({
            'task_id': task.id,
            'user_id': currentUser.id,
            'comment': commentText,
          });
        } catch (_) {
          // Fail silently to prevent status change from breaking if comment fails
        }
      }

      // Update local state
      state.whenData((tasks) {
        state = AsyncValue.data(
          tasks.map((t) => t.id == task.id 
              ? t.copyWith(
                  status: newStatus, 
                  completedAt: finalCompletedAt,
                  actualHours: newStatus == 'completed' ? (actualHours ?? t.actualHours) : t.actualHours,
                ) 
              : t).toList(),
        );
      });

      // Gamification: award EXP only when moving to 'completed'
      if (newStatus == 'completed' && task.status != 'completed') {
        int expReward = 20; // Default
        switch (task.priority) {
          case 'low':
            expReward = 20;
            break;
          case 'medium':
            expReward = 40;
            break;
          case 'high':
            expReward = 75;
            break;
          case 'critical':
            expReward = 120;
            break;
        }

        // Add EXP and return if the user leveled up
        final leveledUp = await _ref.read(userStatsProvider.notifier).addExp(expReward);
        return leveledUp;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignTaskToSelf(ProjectTask task) async {
    try {
      final user = _ref.read(authProvider);
      if (user == null) return;

      // Update in Supabase
      await Supabase.instance.client
          .from('project_tasks')
          .update({'assigned_to': user.id})
          .eq('id', task.id);

      // Update local state
      state.whenData((tasks) {
        state = AsyncValue.data(
          tasks.map((t) => t.id == task.id 
              ? t.copyWith(assignedTo: user.id) 
              : t).toList(),
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createTask({
    required String title,
    required String description,
    required String? projectId,
    required String priority,
  }) async {
    try {
      final user = _ref.read(authProvider);
      if (user == null) return;

      final newTaskMap = {
        'project_id': projectId,
        'title': title,
        'description': description,
        'status': 'todo',
        'priority': priority,
        'assigned_to': user.id,
        'created_by': user.id,
        'estimated_hours': 0.0,
        'actual_hours': 0.0,
        'order_index': 0,
      };

      final response = await Supabase.instance.client
          .from('project_tasks')
          .insert(newTaskMap)
          .select()
          .single();

      final newTask = ProjectTask.fromJson(response);

      state.whenData((tasks) {
        state = AsyncValue.data([newTask, ...tasks]);
      });
    } catch (e) {
      rethrow;
    }
  }
}
