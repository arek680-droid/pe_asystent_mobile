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

      final List<dynamic> data = response as List<dynamic>;
      final tasks = data.map((json) => ProjectTask.fromJson(json as Map<String, dynamic>)).toList();
      
      state = AsyncValue.data(tasks);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> completeTask(ProjectTask task) async {
    try {
      final completedAt = DateTime.now();
      
      // Update status in Supabase
      await Supabase.instance.client
          .from('project_tasks')
          .update({
            'status': 'completed',
            'completed_at': completedAt.toIso8601String(),
          })
          .eq('id', task.id);

      // Update local state
      state.whenData((tasks) {
        state = AsyncValue.data(
          tasks.map((t) => t.id == task.id 
              ? t.copyWith(status: 'completed', completedAt: completedAt) 
              : t).toList(),
        );
      });

      // Gamification: award EXP based on priority
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
    } catch (e) {
      // Re-throw or handle error
      rethrow;
    }
  }

  Future<void> createTask({
    required String title,
    required String description,
    required String projectId,
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
