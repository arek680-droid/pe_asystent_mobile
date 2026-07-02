import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_stats_provider.dart';
import '../providers/update_provider.dart';
import '../providers/avatar_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/realtime_notification_provider.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'task_detail_sheet.dart';

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
      DashboardScreen(
        onNavigateToTasks: () => setState(() => _currentIndex = 1),
        onNavigateToProfile: () => setState(() => _currentIndex = 2),
      ),
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
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Pulpit',
            ),
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

  void _showUpdateDialog(BuildContext context, WidgetRef ref, String currentVersion, String latestVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Aktualizacja'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dostępna jest nowa wersja aplikacji PE Asystent!'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Obecna wersja: '),
                Text(currentVersion, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Nowa wersja: '),
                Text(
                  latestVersion,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Później'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(updateProvider.notifier).launchUpdateUrl();
              Navigator.of(context).pop();
            },
            child: const Text('Aktualizuj'),
          ),
        ],
      ),
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
    // Initialize real-time notifications
    ref.watch(realtimeNotificationProvider);

    // Listen for updates and show a dialog if one is available
    ref.listen<UpdateState>(updateProvider, (previous, next) {
      if (next.hasUpdate && !next.isLoading && next.error == null) {
        _showUpdateDialog(context, ref, next.currentVersion, next.latestVersion);
      }
    });

    final tasksState = ref.watch(tasksProvider);
    final userStats = ref.watch(userStatsProvider);
    final activeAvatarId = ref.watch(avatarProvider);
    final profileState = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final showGamificationSetting = ref.watch(gamificationSettingsProvider).value ?? true;
    final showGamification = showGamificationSetting || isAdmin;

    // Calculate EXP percentage
    final double expProgress = userStats.nextLevelExp > 0 
        ? userStats.exp / userStats.nextLevelExp 
        : 0.0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0, // Hide standard toolbar, we build our own gamified header
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(showGamification ? 220 : 110),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gamified Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular 2D Pet Avatar
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                          backgroundImage: AssetImage('assets/avatars/png/$activeAvatarId.png'),
                        ),
                      ),
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
                              profileState.value ?? ref.read(authProvider)?.email?.split('@')[0] ?? 'Użytkownik',
                              style: theme.textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      if (showGamification) ...[
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
                    ],
                  ),
                  if (showGamification) ...[
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
                  ],
                  const SizedBox(height: 16),
                  // Tabbar
                  TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.secondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Moje zadania'),
                      Tab(text: 'Nieprzypisane'),
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
            final currentUser = ref.watch(authProvider);
            final currentUserId = currentUser?.id;

            final myTasks = tasks.where((t) => t.status != 'completed' && t.assignedTo == currentUserId).toList();
            final unassignedTasks = tasks.where((t) => t.status != 'completed' && (t.assignedTo == null || t.assignedTo!.isEmpty)).toList();
            final completedTasks = tasks.where((t) => t.status == 'completed').toList();

            Future<void> handleStatusChanged(ProjectTask task, String newStatus) async {
              final oldStatus = task.status;
              if (oldStatus == newStatus) return;

              if (newStatus == 'on_hold') {
                final reason = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    final controller = TextEditingController();
                    final formKey = GlobalKey<FormState>();
                    final dialogTheme = Theme.of(context);
                    return AlertDialog(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Powód wstrzymania'),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      content: Form(
                        key: formKey,
                        child: TextFormField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Wpisz powód wstrzymania...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wpisanie powodu jest wymagane';
                            }
                            return null;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Anuluj', style: TextStyle(color: dialogTheme.colorScheme.secondary)),
                        ),
                        TextButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(context).pop(controller.text.trim());
                            }
                          },
                          child: Text('Zatwierdź', style: TextStyle(color: dialogTheme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );

                if (reason == null || reason.trim().isEmpty) {
                  return;
                }

                // Add comment to the database
                if (currentUser != null) {
                  try {
                    await Supabase.instance.client.from('project_task_comments').insert({
                      'task_id': task.id,
                      'user_id': currentUser.id,
                      'comment': '[WSTRZYMANO] $reason',
                    });
                  } catch (_) {
                    // Fail silently
                  }
                }
              }

              final leveledUp = await ref.read(tasksProvider.notifier).updateTaskStatus(task, newStatus);

              if (context.mounted) {
                String statusLabel = '';
                switch (newStatus) {
                  case 'todo': statusLabel = 'Do zrobienia'; break;
                  case 'in_progress': statusLabel = 'W trakcie'; break;
                  case 'on_hold': statusLabel = 'Wstrzymano'; break;
                  case 'to_accept': statusLabel = 'Do akceptacji'; break;
                  case 'completed': statusLabel = 'Zakończone'; break;
                }

                if (newStatus == 'completed') {
                  final expBonus = task.priority == 'critical' ? 120 : task.priority == 'high' ? 75 : task.priority == 'medium' ? 40 : 20;
                  final message = showGamification 
                      ? 'Zadanie ukończone! +$expBonus EXP'
                      : 'Zadanie zostało ukończone!';
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                  if (showGamification && leveledUp) {
                    _celebrateLevelUp(context, ref.read(userStatsProvider).level);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Zmieniono status na: $statusLabel'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            Future<void> handleAssignToSelf(ProjectTask task) async {
              await ref.read(tasksProvider.notifier).assignTaskToSelf(task);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zadanie zostało przypisane do Ciebie!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return Column(
              children: [
                const TaskActivityLegend(),
                Expanded(
                  child: TabBarView(
                    children: [
                      TaskList(
                        tasks: myTasks,
                        onStatusChanged: handleStatusChanged,
                        isEmptyMessage: 'Brak zadań przypisanych do Ciebie. Odpocznij!',
                      ),
                      TaskList(
                        tasks: unassignedTasks,
                        onStatusChanged: handleStatusChanged,
                        isEmptyMessage: 'Brak nieprzypisanych zadań w systemie.',
                        isUnassignedTab: true,
                        onAssignToSelf: handleAssignToSelf,
                      ),
                      TaskList(
                        tasks: completedTasks,
                        onStatusChanged: handleStatusChanged,
                        isEmptyMessage: 'Jeszcze nic nie ukończyłeś. Do dzieła!',
                      ),
                    ],
                  ),
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
  final Function(ProjectTask, String) onStatusChanged;
  final String isEmptyMessage;
  final bool isUnassignedTab;
  final Function(ProjectTask)? onAssignToSelf;

  const TaskList({
    super.key,
    required this.tasks,
    required this.onStatusChanged,
    required this.isEmptyMessage,
    this.isUnassignedTab = false,
    this.onAssignToSelf,
  });

  Widget _buildDaysBadge(DateTime createdAt, ThemeData theme) {
    final difference = DateTime.now().difference(createdAt).inDays;
    final days = difference < 0 ? 0 : difference;
    
    Color textColor;
    String label;
    bool showDot = true;

    if (days < 3) {
      textColor = Colors.green.shade600;
      label = "$days ${days == 1 ? 'dzień' : 'dni'}";
    } else if (days >= 14) {
      textColor = Colors.red.shade600;
      label = "$days ${days == 1 ? 'dzień' : 'dni'}";
    } else if (days >= 7) {
      textColor = Colors.orange.shade600;
      label = "$days ${days == 1 ? 'dzień' : 'dni'}";
    } else {
      textColor = theme.colorScheme.secondary.withValues(alpha: 0.6);
      label = "$days ${days == 1 ? 'dzień' : 'dni'}";
      showDot = false;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'todo': return Icons.radio_button_unchecked;
      case 'in_progress': return Icons.pending_actions_rounded;
      case 'on_hold': return Icons.pause_circle_filled_rounded;
      case 'to_accept': return Icons.fact_check_rounded;
      case 'completed': return Icons.check_circle_rounded;
      default: return Icons.radio_button_unchecked;
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

  void _showAssignDialog(BuildContext context, ProjectTask task) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Przypisać zadanie?'),
        content: const Text('Czy chcesz przypisać to zadanie do siebie?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Anuluj', style: TextStyle(color: theme.colorScheme.secondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onAssignToSelf != null) {
                onAssignToSelf!(task);
              }
            },
            child: Text('Przypisz', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStatusBottomSheet(BuildContext context, ProjectTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final statuses = [
          {'value': 'todo', 'label': 'Do zrobienia'},
          {'value': 'in_progress', 'label': 'W trakcie'},
          {'value': 'on_hold', 'label': 'Wstrzymano'},
          {'value': 'to_accept', 'label': 'Do akceptacji'},
          {'value': 'completed', 'label': 'Zakończone'},
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Zmień status zadania',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...statuses.map((status) {
                final isSelected = task.status == status['value'];
                final value = status['value'] as String;
                final label = status['label'] as String;
                final color = _getStatusColor(value);
                final icon = _getStatusIcon(value);

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.secondary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    onStatusChanged(task, value);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
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
        final theme = Theme.of(context);
        final priorityColor = _getPriorityColor(task.priority);
        final statusColor = _getStatusColor(task.status);
        final statusIcon = _getStatusIcon(task.status);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => TaskDetailSheet(task: task),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status selector button or Assign to self button + Image indicator
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: isUnassignedTab 
                                ? () => _showAssignDialog(context, task)
                                : () => _showStatusBottomSheet(context, task),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isUnassignedTab 
                                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                    : statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isUnassignedTab ? Icons.person_add_alt_1_rounded : statusIcon,
                                color: isUnassignedTab ? theme.colorScheme.primary : statusColor,
                                size: 22,
                              ),
                            ),
                          ),
                          if (task.hasImage) ...[
                            const SizedBox(height: 8),
                            Icon(
                              Icons.image_outlined,
                              size: 16,
                              color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                            ),
                          ],
                        ],
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
                               if (task.createdAt != null) ...[
                                 const SizedBox(width: 8),
                                 Container(
                                   width: 4,
                                   height: 4,
                                   decoration: BoxDecoration(
                                     color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                     shape: BoxShape.circle,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 _buildDaysBadge(task.createdAt!, theme),
                               ],
                               const Spacer(),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getStatusLabel(task.status).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: task.status == 'completed'
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  color: task.status == 'completed'
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

// --- TASK ACTIVITY LEGEND ---

class TaskActivityLegend extends StatelessWidget {
  const TaskActivityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.query_stats_rounded,
              size: 14,
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Brak aktywności: ',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.secondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            _buildDot(Colors.green.shade600, '< 3 dni'),
            const SizedBox(width: 12),
            _buildDot(Colors.orange.shade600, '> 7 dni'),
            const SizedBox(width: 12),
            _buildDot(Colors.red.shade600, '> 14 dni'),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
                  isExpanded: true,
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(hintText: 'Wybierz projekt'),
                  items: projects.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            Text(
              'Priorytet',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
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
                textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
              ),
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
