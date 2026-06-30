import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SUBTASKS PROVIDER ---

class Subtask {
  final String id;
  final String parentTaskId;
  final String title;
  final String status; // 'to_do' | 'completed'

  Subtask({
    required this.id,
    required this.parentTaskId,
    required this.title,
    required this.status,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id']?.toString() ?? '',
      parentTaskId: json['parent_task_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'to_do',
    );
  }

  Subtask copyWith({
    String? id,
    String? parentTaskId,
    String? title,
    String? status,
  }) {
    return Subtask(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}

final subtasksProvider = StateNotifierProvider.family<SubtasksNotifier, AsyncValue<List<Subtask>>, String>((ref, taskId) {
  return SubtasksNotifier(taskId);
});

class SubtasksNotifier extends StateNotifier<AsyncValue<List<Subtask>>> {
  final String taskId;
  SubtasksNotifier(this.taskId) : super(const AsyncValue.loading()) {
    fetchSubtasks();
  }

  Future<void> fetchSubtasks() async {
    try {
      final response = await Supabase.instance.client
          .from('project_subtasks')
          .select('*')
          .eq('parent_task_id', taskId)
          .order('display_order', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final subtasks = data.map((json) => Subtask.fromJson(json)).toList();
      state = AsyncValue.data(subtasks);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleSubtask(Subtask subtask) async {
    final newStatus = subtask.status == 'completed' ? 'to_do' : 'completed';
    
    // Optimistic UI update
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((st) => st.id == subtask.id ? st.copyWith(status: newStatus) : st).toList(),
      );
    });

    try {
      await Supabase.instance.client
          .from('project_subtasks')
          .update({'status': newStatus})
          .eq('id', subtask.id);
    } catch (e) {
      // Revert on error
      fetchSubtasks();
    }
  }

  Future<void> addSubtask(String title) async {
    if (title.trim().isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final currentList = state.value ?? [];
      final displayOrder = currentList.length;

      final response = await Supabase.instance.client
          .from('project_subtasks')
          .insert({
            'parent_task_id': taskId,
            'title': title.trim(),
            'status': 'to_do',
            'display_order': displayOrder,
            'created_by': user?.id,
          })
          .select()
          .single();

      final newSubtask = Subtask.fromJson(response);
      state.whenData((list) {
        state = AsyncValue.data([...list, newSubtask]);
      });
    } catch (e) {
      // Handle error
    }
  }
}

// --- COMMENTS PROVIDER ---

class TaskComment {
  final String id;
  final String taskId;
  final String comment;
  final String userName;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.comment,
    required this.userName,
    required this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    // Extract display name from user_profiles relation
    String senderName = 'Użytkownik';
    final profile = json['user_profiles'];
    if (profile != null) {
      senderName = profile['display_name']?.toString() ?? 
                   profile['email']?.toString().split('@')[0] ?? 
                   'Użytkownik';
    }

    return TaskComment(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      userName: senderName,
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }
}

final commentsProvider = StateNotifierProvider.family<CommentsNotifier, AsyncValue<List<TaskComment>>, String>((ref, taskId) {
  return CommentsNotifier(taskId);
});

class CommentsNotifier extends StateNotifier<AsyncValue<List<TaskComment>>> {
  final String taskId;
  CommentsNotifier(this.taskId) : super(const AsyncValue.loading()) {
    fetchComments();
  }

  Future<void> fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('project_task_comments')
          .select('*, user_profiles:user_id(display_name, email)')
          .eq('task_id', taskId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final comments = data.map((json) => TaskComment.fromJson(json)).toList();
      state = AsyncValue.data(comments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addComment(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('project_task_comments')
          .insert({
            'task_id': taskId,
            'user_id': user.id,
            'comment': text.trim(),
          })
          .select('*, user_profiles:user_id(display_name, email)')
          .single();

      final newComment = TaskComment.fromJson(response);
      state.whenData((list) {
        state = AsyncValue.data([newComment, ...list]);
      });
    } catch (e) {
      // Handle error
    }
  }
}

// --- ATTACHMENTS PROVIDER ---

class TaskAttachment {
  final String id;
  final String taskId;
  final String fileUrl;
  final String fileType;
  final String? fileName;

  TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileUrl,
    required this.fileType,
    this.fileName,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    final filePath = json['file_path']?.toString() ?? '';
    
    // Generate the public URL from the project-images storage bucket
    String url = '';
    if (filePath.isNotEmpty) {
      url = Supabase.instance.client.storage
          .from('project-images')
          .getPublicUrl(filePath);
    }

    return TaskAttachment(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      fileUrl: url,
      fileType: json['file_type']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
    );
  }

  bool get isImage {
    final url = fileUrl.trim().toLowerCase();
    final type = fileType.trim().toLowerCase();
    return url.isNotEmpty && (
      type.contains('image') ||
      url.contains('.png') ||
      url.contains('.jpg') ||
      url.contains('.jpeg') ||
      url.contains('.gif') ||
      url.contains('.webp')
    );
  }
}

final attachmentsProvider = StateNotifierProvider.family<AttachmentsNotifier, AsyncValue<List<TaskAttachment>>, String>((ref, taskId) {
  return AttachmentsNotifier(taskId);
});

class AttachmentsNotifier extends StateNotifier<AsyncValue<List<TaskAttachment>>> {
  final String taskId;
  AttachmentsNotifier(this.taskId) : super(const AsyncValue.loading()) {
    fetchAttachments();
  }

  Future<void> fetchAttachments() async {
    try {
      final response = await Supabase.instance.client
          .from('project_task_attachments')
          .select('*')
          .eq('task_id', taskId);

      final List<dynamic> data = response as List<dynamic>;
      
      final attachments = data.map((json) => TaskAttachment.fromJson(json as Map<String, dynamic>)).toList();
      state = AsyncValue.data(attachments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

