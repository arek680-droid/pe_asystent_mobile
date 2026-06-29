import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_task.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_stats_provider.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const TasksDashboard(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Zadania',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class TasksDashboard extends ConsumerWidget {
  const TasksDashboard({super.key});

  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddTaskBottomSheet(),
    );
  }

  void _celebrateLevelUp(BuildContext context, int newLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AWANS!',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Twój poziom wzrósł!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Poziom ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '${newLevel - 1}',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                  Text(
                    '$newLevel',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ekstra!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final userStats = ref.watch(userStatsProvider);
    final theme = Theme.of(context);

    // Calculate EXP percentage
    final double expProgress = userStats.nextLevelExp > 0 
        ? userStats.exp / userStats.nextLevelExp 
        : 0.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0, // Hide standard toolbar, we build our own gamified header
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(160),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gamified Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Witaj w PE Asystent',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ref.read(authProvider)?.email?.split('@')[0] ?? 'Użytkownik',
                              style: theme.textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'LVL ${userStats.level}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // EXP progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Doświadczenie (EXP)',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                          Text(
                            '${userStats.exp} / ${userStats.nextLevelExp} EXP',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.dividerTheme.color ?? Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            widthFactor: expProgress,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tabbar
                  TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal),
                    tabs: const [
                      Tab(text: 'Do zrobienia'),
                      Tab(text: 'Zakończone'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: tasksState.when(
          data: (tasks) {
            final activeTasks = tasks.where((t) => t.status != 'completed').toList();
            final completedTasks = tasks.where((t) => t.status == 'completed').toList();

            return TabBarView(
              children: [
                TaskList(
                  tasks: activeTasks,
                  onComplete: (task) async {
                    final leveledUp = await ref.read(tasksProvider.notifier).completeTask(task);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Zadanie ukończone! +${task.priority == 'critical' ? 120 : task.priority == 'high' ? 75 : task.priority == 'medium' ? 40 : 20} EXP'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                      if (leveledUp) {
                        _celebrateLevelUp(context, ref.read(userStatsProvider).level);
                      }
                    }
                  },
                  isEmptyMessage: 'Brak aktywnych zadań. Odpocznij!',
                ),
                TaskList(
                  tasks: completedTasks,
                  isEmptyMessage: 'Jeszcze nic nie ukończyłeś. Do dzieła!',
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Błąd połączenia: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(tasksProvider.notifier).fetchTasks(),
                    child: const Text('Spróbuj ponownie'),
                  )
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddTaskSheet(context, ref),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.scaffoldBackgroundColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  final List<ProjectTask> tasks;
  final Function(ProjectTask)? onComplete;
  final String isEmptyMessage;

  const TaskList({
    super.key,
    required this.tasks,
    this.onComplete,
    required this.isEmptyMessage,
  });

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          isEmptyMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final priorityColor = _getPriorityColor(task.priority);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Task details sheet if wanted later
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onComplete != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0, top: 2),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) => onComplete!(task),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: priorityColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                task.priority.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: priorityColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: onComplete == null 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  color: onComplete == null 
                                      ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                                      : null,
                                ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              task.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AddTaskBottomSheet extends ConsumerStatefulWidget {
  const AddTaskBottomSheet({super.key});

  @override
  ConsumerState<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends ConsumerState<AddTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedProjectId;
  String _selectedPriority = 'medium';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz projekt')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(tasksProvider.notifier).createTask(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            projectId: _selectedProjectId!,
            priority: _selectedPriority,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas dodawania: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nowe Zadanie',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Tytuł zadania'),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Wprowadź tytuł';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(hintText: 'Opis (opcjonalnie)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Project dropdown
            projectsState.when(
              data: (projects) {
                if (projects.isEmpty) {
                  return Text(
                    'Brak projektów w bazie danych. Dodaj projekt najpierw w aplikacji webowej.',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(hintText: 'Wybierz projekt'),
                  items: projects.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProjectId = val;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => Text('Nie udało się załadować projektów: $err'),
            ),
            const SizedBox(height: 16),

            // Priority Selector
            Row(
              children: [
                Text('Priorytet:', style: theme.textTheme.bodyLarge),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Niski')),
                      ButtonSegment(value: 'medium', label: Text('Śred')),
                      ButtonSegment(value: 'high', label: Text('Wys')),
                      ButtonSegment(value: 'critical', label: Text('Kryt')),
                    ],
                    selected: {_selectedPriority},
                    onSelectionChanged: (set) {
                      setState(() {
                        _selectedPriority = set.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveTask,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Utwórz zadanie'),
            ),
          ],
        ),
      ),
    );
  }
}
