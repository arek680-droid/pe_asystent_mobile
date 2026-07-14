import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/todo_note.dart';
import 'auth_provider.dart';
import '../services/log_service.dart';

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

  Future<void> updateTodoNote({
    required String id,
    required String title,
    required String priority,
  }) async {
    // Optimistic UI update
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((n) => n.id == id ? n.copyWith(title: title, priority: priority) : n).toList(),
      );
    });

    try {
      await Supabase.instance.client
          .from('todo_notes')
          .update({
            'title': title,
            'priority': priority,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      fetchTodoNotes();
      rethrow;
    }
  }

  @override
  set state(AsyncValue<List<TodoNote>> value) {
    super.state = value;
    if (value is AsyncData<List<TodoNote>>) {
      _updateHomeWidget();
    }
  }

  Future<void> _updateHomeWidget() async {
    try {
      final list = state.value ?? [];
      final active = list.where((n) => !n.completed).toList();
      
      LogService().addLog('[HomeWidget] Zapisywanie widżetu: aktywne=${active.length}');
      
      await HomeWidget.saveWidgetData<int>('todo_count', active.length);
      await HomeWidget.saveWidgetData<String?>('todo_1', active.isNotEmpty ? active[0].title : null);
      await HomeWidget.saveWidgetData<String?>('todo_2', active.length > 1 ? active[1].title : null);
      await HomeWidget.saveWidgetData<String?>('todo_3', active.length > 2 ? active[2].title : null);
      await HomeWidget.saveWidgetData<String?>('todo_4', active.length > 3 ? active[3].title : null);
      
      final res = await HomeWidget.updateWidget(
        name: 'TodoWidgetProvider',
        androidName: 'TodoWidgetProvider',
        qualifiedAndroidName: 'com.example.pe_asystent_mobile.TodoWidgetProvider',
      );
      LogService().addLog('[HomeWidget] Aktualizacja wysłana, wynik=$res');
    } catch (e, stack) {
      LogService().addLog('[HomeWidget] Błąd: $e');
      debugPrint('Error updating home widget: $e\n$stack');
    }
  }
}

final launchActionProvider = StateProvider<String?>((ref) => null);
