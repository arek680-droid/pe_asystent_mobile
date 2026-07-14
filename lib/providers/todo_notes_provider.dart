import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_note.dart';
import 'auth_provider.dart';

final todoNotesProvider = StateNotifierProvider<TodoNotesNotifier, AsyncValue<List<TodoNote>>>((ref) {
  return TodoNotesNotifier(ref);
});

class TodoNotesNotifier extends StateNotifier<AsyncValue<List<TodoNote>>> {
  final Ref _ref;

  TodoNotesNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchTodoNotes();
  }

  Future<void> fetchTodoNotes() async {
    final user = _ref.read(authProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('todo_notes')
          .select('*')
          .eq('user_id', user.id)
          .order('position', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final notes = data.map((json) => TodoNote.fromJson(json as Map<String, dynamic>)).toList();
      state = AsyncValue.data(notes);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createTodoNote({
    required String title,
    required String priority,
  }) async {
    final user = _ref.read(authProvider);
    if (user == null) return;

    try {
      final currentList = state.value ?? [];
      final position = currentList.length;

      final response = await Supabase.instance.client
          .from('todo_notes')
          .insert({
            'user_id': user.id,
            'title': title,
            'completed': false,
            'priority': priority,
            'position': position,
          })
          .select()
          .single();

      final newNote = TodoNote.fromJson(response);
      state.whenData((list) {
        state = AsyncValue.data([...list, newNote]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleTodoNote(TodoNote note) async {
    final newCompleted = !note.completed;
    
    // Optimistic UI update
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((n) => n.id == note.id ? n.copyWith(completed: newCompleted) : n).toList(),
      );
    });

    try {
      await Supabase.instance.client
          .from('todo_notes')
          .update({
            'completed': newCompleted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', note.id);
    } catch (e) {
      fetchTodoNotes();
      rethrow;
    }
  }

  Future<void> deleteTodoNote(String id) async {
    // Optimistic UI update
    state.whenData((list) {
      state = AsyncValue.data(
        list.where((n) => n.id != id).toList(),
      );
    });

    try {
      await Supabase.instance.client
          .from('todo_notes')
          .delete()
          .eq('id', id);
    } catch (e) {
      fetchTodoNotes();
      rethrow;
    }
  }
}
