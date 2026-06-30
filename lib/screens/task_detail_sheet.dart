import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_task.dart';
import '../providers/task_details_provider.dart';

class TaskDetailSheet extends ConsumerStatefulWidget {
  final ProjectTask task;
  const TaskDetailSheet({super.key, required this.task});

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _subtaskController = TextEditingController();
  bool _isAddingSubtask = false;

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical': return Colors.red.shade600;
      case 'high': return Colors.orange.shade600;
      case 'medium': return Colors.blue.shade600;
      default: return Colors.grey.shade600;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'todo': return Colors.grey;
      case 'in_progress': return Colors.blue;
      case 'on_hold': return Colors.orange;
      case 'to_accept': return Colors.purple;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'todo': return 'Do zrobienia';
      case 'in_progress': return 'W trakcie';
      case 'on_hold': return 'Wstrzymano';
      case 'to_accept': return 'Do akceptacji';
      case 'completed': return 'Zakończone';
      default: return '';
    }
  }

  void _showCommentsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CommentsBottomSheet(taskId: widget.task.id),
    );
  }

  void _openImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Interactive Zoomable Image
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.9),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Nie udało się załadować podglądu',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasksState = ref.watch(subtasksProvider(widget.task.id));
    final commentsState = ref.watch(commentsProvider(widget.task.id));
    final attachmentsState = ref.watch(attachmentsProvider(widget.task.id));
    final theme = Theme.of(context);
    final priorityColor = _getPriorityColor(widget.task.priority);
    final statusColor = _getStatusColor(widget.task.status);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Scrollable Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 80), // extra padding at bottom for FAB
            child: CustomScrollView(
              slivers: [
                // Drag Handle & Title
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Badges Row
                      Row(
                        children: [
                          // Priority
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.priority.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusLabel(widget.task.status).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Task Title
                      Text(
                        widget.task.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        'Opis',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.task.description.isNotEmpty 
                            ? widget.task.description 
                            : 'Brak opisu.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Tags Section
                      if (widget.task.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.task.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_offer_outlined,
                                    size: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Attachments Section
                      attachmentsState.when(
                        data: (attachments) {
                          final images = attachments.where((a) => a.isImage && a.fileUrl.trim().isNotEmpty).toList();
                          if (images.isEmpty) return const SizedBox.shrink();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zdjęcia / Załączniki',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  itemBuilder: (context, idx) {
                                    final img = images[idx];
                                    return GestureDetector(
                                      onTap: () => _openImagePreview(context, img.fileUrl),
                                      child: Container(
                                        width: 100,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Image.network(
                                            img.fileUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                                                child: const Center(
                                                  child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.red),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),
                      
                      // Subtasks Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lista prac',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isAddingSubtask = true;
                              });
                            },
                            icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Subtasks List
                subtasksState.when(
                  data: (subtasks) {
                    if (subtasks.isEmpty && !_isAddingSubtask) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            'Brak dodanych prac.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == subtasks.length) {
                            // Inline new subtask input field
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _subtaskController,
                                      decoration: const InputDecoration(
                                        hintText: 'Wpisz nową pracę...',
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      autofocus: true,
                                      onSubmitted: (value) {
                                        if (value.trim().isNotEmpty) {
                                          ref.read(subtasksProvider(widget.task.id).notifier).addSubtask(value);
                                          _subtaskController.clear();
                                        }
                                        setState(() {
                                          _isAddingSubtask = false;
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      if (_subtaskController.text.trim().isNotEmpty) {
                                        ref.read(subtasksProvider(widget.task.id).notifier).addSubtask(_subtaskController.text);
                                        _subtaskController.clear();
                                      }
                                      setState(() {
                                        _isAddingSubtask = false;
                                      });
                                    },
                                    icon: const Icon(Icons.check, color: Colors.green),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isAddingSubtask = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          final subtask = subtasks[index];
                          final isCompleted = subtask.status == 'completed';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: InkWell(
                              onTap: () {
                                ref.read(subtasksProvider(widget.task.id).notifier).toggleSubtask(subtask);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                                child: Row(
                                  children: [
                                    // Checkbox Icon
                                    Icon(
                                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isCompleted ? Colors.green : Colors.grey.shade400,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        subtask.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          color: isCompleted ? theme.colorScheme.secondary.withValues(alpha: 0.5) : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: subtasks.length + (_isAddingSubtask ? 1 : 0),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: Text('Błąd ładowania podzadań: $err'),
                  ),
                ),
              ],
            ),
          ),

          // Floating Chat Bubble at the bottom right
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: () => _showCommentsBottomSheet(context),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.scaffoldBackgroundColor,
              shape: const CircleBorder(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 24),
                  commentsState.when(
                    data: (comments) {
                      if (comments.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${comments.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- COMMENTS BOTTOM SHEET ---

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String taskId;
  const CommentsBottomSheet({super.key, required this.taskId});

  @override
  ConsumerState<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsState = ref.watch(commentsProvider(widget.taskId));
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag Handle
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Komentarze',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Comments List
            Expanded(
              child: commentsState.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'Brak komentarzy. Bądź pierwszym, który skomentuje!',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      // Format time (e.g. 15:30)
                      final timeString = '${comment.createdAt.hour.toString().padLeft(2, '0')}:${comment.createdAt.minute.toString().padLeft(2, '0')}';
                      final dateString = '${comment.createdAt.day}.${comment.createdAt.month}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.05)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      comment.userName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$dateString o $timeString',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comment.comment,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Błąd ładowania komentarzy: $err')),
              ),
            ),

            // Comment Input Field
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Napisz komentarz...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final text = _commentController.text.trim();
                      if (text.isNotEmpty) {
                        ref.read(commentsProvider(widget.taskId).notifier).addComment(text);
                        _commentController.clear();
                      }
                    },
                    icon: Icon(Icons.send, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
