import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_stats_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/project_provider.dart';
import '../models/project_task.dart';
import '../models/project.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/log_hours_dialog.dart';
import 'task_detail_sheet.dart';

enum ActivityType {
  comment,
  newTask,
  completedTask,
}

// Model for recent activity shown in the dashboard feed (combines comments, new tasks, and completed tasks)
class DashboardActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String content;
  final DateTime createdAt;
  final String taskTitle;
  final String taskId;
  final String authorName;

  DashboardActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.taskTitle,
    required this.taskId,
    required this.authorName,
  });
}

// Provider to fetch and combine recent comments, new tasks, and completed tasks into a single feed of 10 items
final recentActivityProvider = FutureProvider.autoDispose<List<DashboardActivityItem>>((ref) async {
  // 1. Fetch 10 most recent comments
  final commentsResponse = await Supabase.instance.client
      .from('project_task_comments')
      .select('id, comment, created_at, task_id, project_tasks(title), user_profiles(display_name)')
      .order('created_at', ascending: false)
      .limit(10);

  // 2. Fetch 10 most recent tasks
  final tasksResponse = await Supabase.instance.client
      .from('project_tasks')
      .select('id, title, description, created_at, creator:user_profiles!project_tasks_created_by_fkey(display_name)')
      .order('created_at', ascending: false)
      .limit(10);

  // 3. Fetch 10 most recently completed tasks
  final completedResponse = await Supabase.instance.client
      .from('project_tasks')
      .select('id, title, completed_at, assignee:user_profiles!project_tasks_assigned_to_fkey(display_name)')
      .eq('status', 'completed')
      .not('completed_at', 'is', null)
      .order('completed_at', ascending: false)
      .limit(10);

  final List<dynamic> commentsData = commentsResponse as List<dynamic>;
  final List<dynamic> tasksData = tasksResponse as List<dynamic>;
  final List<dynamic> completedData = completedResponse as List<dynamic>;

  final List<DashboardActivityItem> items = [];

  // Map comments
  for (final json in commentsData) {
    final taskMap = json['project_tasks'] as Map<String, dynamic>?;
    final profileMap = json['user_profiles'] as Map<String, dynamic>?;
    
    items.add(DashboardActivityItem(
      id: json['id']?.toString() ?? '',
      type: ActivityType.comment,
      title: 'Komentarz',
      content: json['comment']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      taskTitle: taskMap?['title']?.toString() ?? 'Zadanie',
      taskId: json['task_id']?.toString() ?? '',
      authorName: profileMap?['display_name']?.toString() ?? 'Użytkownik',
    ));
  }

  // Map new tasks
  for (final json in tasksData) {
    final profileMap = json['creator'] as Map<String, dynamic>?;
    final taskTitle = json['title']?.toString() ?? 'Bez tytułu';
    
    items.add(DashboardActivityItem(
      id: json['id']?.toString() ?? '',
      type: ActivityType.newTask,
      title: 'Nowe zadanie',
      content: taskTitle,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      taskTitle: taskTitle,
      taskId: json['id']?.toString() ?? '',
      authorName: profileMap?['display_name']?.toString() ?? 'System',
    ));
  }

  // Map completed tasks
  for (final json in completedData) {
    final profileMap = json['assignee'] as Map<String, dynamic>?;
    final taskTitle = json['title']?.toString() ?? 'Bez tytułu';
    
    items.add(DashboardActivityItem(
      id: json['id']?.toString() ?? '',
      type: ActivityType.completedTask,
      title: 'Ukończono zadanie',
      content: taskTitle,
      createdAt: DateTime.tryParse(json['completed_at']?.toString() ?? '') ?? DateTime.now(),
      taskTitle: taskTitle,
      taskId: json['id']?.toString() ?? '',
      authorName: profileMap?['display_name']?.toString() ?? 'Pracownik',
    ));
  }

  // Sort combined list by createdAt descending
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Limit to top 10 items
  return items.take(10).toList();
});

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNavigateToTasks;
  final VoidCallback onNavigateToProfile;

  const DashboardScreen({
    super.key,
    required this.onNavigateToTasks,
    required this.onNavigateToProfile,
  });

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} dni temu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} godz. temu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min. temu';
    } else {
      return 'przed chwilą';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final profileNameAsync = ref.watch(profileProvider);
    final userStats = ref.watch(userStatsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final activityAsync = ref.watch(recentActivityProvider);
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final showGamificationSetting = ref.watch(gamificationSettingsProvider).value ?? true;
    final showGamification = showGamificationSetting || isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(tasksProvider);
            ref.invalidate(recentActivityProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Welcome & Level Badge)
                profileNameAsync.when(
                  data: (displayName) {
                    final name = displayName ?? user?.email?.split('@').first ?? 'Użytkownik';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cześć, $name! 👋',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Oto podsumowanie Twojego dnia pracy.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Mini Level Circle
                        if (showGamification) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Lvl ${userStats.level}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 50),
                  error: (err, stack) => const SizedBox(height: 50),
                ),
                const SizedBox(height: 24),

                // 2. Gamification / XP Card
                if (showGamification) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surfaceContainerLow,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Postęp Poziomu',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${userStats.exp} / ${userStats.nextLevelExp} EXP',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: userStats.nextLevelExp > 0 ? userStats.exp / userStats.nextLevelExp : 0.0,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zdobądź jeszcze ${userStats.nextLevelExp - userStats.exp} EXP, aby awansować!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 2.5. Zadania w trakcie (Current Focus)
                tasksAsync.when(
                  data: (tasks) {
                    final myInProgressTasks = tasks.where((t) => t.assignedTo == user?.id && t.status == 'in_progress').toList();
                    return Column(
                      children: [
                        _buildInProgressSection(context, ref, myInProgressTasks, tasks, user?.id),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 50, child: Center(child: LinearProgressIndicator())),
                  error: (err, stack) => const SizedBox(),
                ),

                // 3. Task Overview Grid & Completion Circle
                Text(
                  'Twoje Statystyki',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                tasksAsync.when(
                  data: (tasks) {
                    final myActiveTasks = tasks.where((t) => t.assignedTo == user?.id && t.status != 'completed').length;
                    final unassignedTasks = tasks.where((t) => (t.assignedTo == null || t.assignedTo!.isEmpty) && t.status != 'completed').length;
                    final completedTasks = tasks.where((t) => t.assignedTo == user?.id && t.status == 'completed').length;
                    final teamCompletedTasks = tasks.where((t) => t.status == 'completed').length;
                    final overdueTasks = tasks.where((t) => t.status != 'completed' && t.dueDate != null && t.dueDate!.isBefore(DateTime.now())).length;
                    final totalTasks = tasks.length;
                    final completionPercent = totalTasks > 0 ? (teamCompletedTasks / totalTasks * 100).round() : 0;

                    final statsGrid = Column(
                      children: [
                        Row(
                          children: [
                            _buildStatCard(
                              context,
                              title: 'Moje zadania',
                              value: myActiveTasks.toString(),
                              icon: Icons.assignment_ind_rounded,
                              color: Colors.blue,
                              onTap: onNavigateToTasks,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              context,
                              title: 'Nieprzypisane',
                              value: unassignedTasks.toString(),
                              icon: Icons.person_add_alt_1_rounded,
                              color: Colors.amber,
                              onTap: onNavigateToTasks,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatCard(
                              context,
                              title: 'Zakończone',
                              value: completedTasks.toString(),
                              icon: Icons.check_circle_rounded,
                              color: Colors.green,
                              onTap: onNavigateToTasks,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              context,
                              title: 'Opóźnione',
                              value: overdueTasks.toString(),
                              icon: Icons.warning_amber_rounded,
                              color: Colors.red,
                              onTap: onNavigateToTasks,
                            ),
                          ],
                        ),
                      ],
                    );

                    final progressCard = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: Stack(
                              children: [
                                Center(
                                  child: SizedBox(
                                    height: 64,
                                    width: 64,
                                    child: CircularProgressIndicator(
                                      value: completionPercent / 100,
                                      strokeWidth: 7,
                                      backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '$completionPercent%',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wskaźnik ukończenia',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Procent zakończonych zadań w całym zespole.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    final bool isMobile = MediaQuery.of(context).size.width < 600;

                    if (isMobile) {
                      return Column(
                        children: [
                          statsGrid,
                          const SizedBox(height: 16),
                          progressCard,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        // Left: 2x2 Grid of numbers
                        Expanded(
                          flex: 3,
                          child: statsGrid,
                        ),
                        const SizedBox(width: 16),
                        // Right: Circular Progress Card
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            height: 140,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: SizedBox(
                                          height: 54,
                                          width: 54,
                                          child: CircularProgressIndicator(
                                            value: completionPercent / 100,
                                            strokeWidth: 6,
                                            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          '$completionPercent%',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Ukończone',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Błąd statystyk: $err')),
                ),
                const SizedBox(height: 28),

                // 4. Recent Activity Feed (Comments + New Tasks)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ostatnia Aktywność',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: onNavigateToTasks,
                      child: Text(
                        'Zobacz zadania',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                activityAsync.when(
                  data: (activities) {
                    if (activities.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Brak ostatniej aktywności w zespole.',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activities.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final activity = activities[idx];
                        final isComment = activity.type == ActivityType.comment;
                        final isCompleted = activity.type == ActivityType.completedTask;
                        
                        Color iconBgColor;
                        Color iconColor;
                        IconData iconData;
                        String verb;
                        
                        if (isComment) {
                          iconBgColor = Colors.blue.withValues(alpha: 0.1);
                          iconColor = Colors.blue;
                          iconData = Icons.chat_bubble_outline_rounded;
                          verb = ' dodał(a) komentarz:';
                        } else if (isCompleted) {
                          iconBgColor = Colors.green.withValues(alpha: 0.1);
                          iconColor = Colors.green;
                          iconData = Icons.check_circle_outline_rounded;
                          verb = ' ukończył(a) zadanie:';
                        } else {
                          iconBgColor = Colors.purple.withValues(alpha: 0.1);
                          iconColor = Colors.purple;
                          iconData = Icons.playlist_add_rounded;
                          verb = ' utworzył(a) zadanie:';
                        }
                        
                        return InkWell(
                          onTap: () {
                            // Find the task in tasks list to open it
                            tasksAsync.whenData((tasks) {
                              try {
                                final task = tasks.firstWhere((t) => t.id == activity.taskId);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => TaskDetailSheet(task: task),
                                );
                              } catch (_) {
                                // Task might be deleted or not loaded yet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nie można otworzyć tego zadania.')),
                                );
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Activity Icon Badge
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: iconColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: activity.authorName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  TextSpan(
                                                    text: verb,
                                                    style: TextStyle(color: theme.colorScheme.secondary.withValues(alpha: 0.8)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getTimeAgo(activity.createdAt),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        activity.content,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: isComment ? FontWeight.normal : FontWeight.w600,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.assignment_outlined, 
                                              size: 12, 
                                              color: theme.colorScheme.primary
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                activity.taskTitle,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.primary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, stack) => Text('Błąd aktywności: $err'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressSection(
    BuildContext context, 
    WidgetRef ref, 
    List<ProjectTask> inProgressTasks, 
    List<ProjectTask> allTasks,
    String? currentUserId,
  ) {
    final theme = Theme.of(context);
    final projectsList = ref.watch(projectsProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktualne Zadanie',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (inProgressTasks.isNotEmpty)
          ...inProgressTasks.map((task) {
            final project = projectsList.firstWhere(
              (p) => p.id == task.projectId, 
              orElse: () => Project(id: '', name: '', description: ''),
            );
            final projectName = project.name.isNotEmpty ? project.name : 'Bez projektu (wrzutka)';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
              ),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => TaskDetailSheet(task: task),
                                  );
                                },
                                child: Text(
                                  task.title,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                projectName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactButton(
                            context,
                            icon: Icons.more_time_rounded,
                            label: 'Dodaj czas',
                            color: theme.colorScheme.primary,
                            onTap: () => _handleLogTimeTask(context, ref, task),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactButton(
                            context,
                            icon: Icons.pause_rounded,
                            label: 'Wstrzymaj',
                            color: Colors.orange.shade800,
                            onTap: () => _handlePauseTask(context, ref, task),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactButton(
                            context,
                            icon: Icons.check_rounded,
                            label: 'Zakończ',
                            color: Colors.green.shade700,
                            isFilled: true,
                            onTap: () => _handleCompleteTask(context, ref, task),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          })
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined, 
                  size: 40, 
                  color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Brak aktywnych zadań w toku',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rozpocznij jedno z przypisanych zadań lub wybierz z listy.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showChooseTaskBottomSheet(context, ref, allTasks, currentUserId),
                    icon: const Icon(Icons.explore_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Co robimy dzisiaj? 🎯',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showChooseTaskBottomSheet(
    BuildContext context, 
    WidgetRef ref, 
    List<ProjectTask> allTasks, 
    String? currentUserId,
  ) {
    final theme = Theme.of(context);
    final projectsList = ref.watch(projectsProvider).value ?? [];

    final myTodoTasks = allTasks.where((t) => t.assignedTo == currentUserId && t.status == 'todo').toList();
    final unassignedActiveTasks = allTasks.where((t) => (t.assignedTo == null || t.assignedTo!.isEmpty) && t.status != 'completed').toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Co robisz dzisiaj? 🎯',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  if (myTodoTasks.isEmpty && unassignedActiveTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Text(
                        'Brak dostępnych zadań do rozpoczęcia.\nStwórz nowe zadanie w zakładce Zadania.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                  if (myTodoTasks.isNotEmpty) ...[
                    Text(
                      'TWOJE ZADANIA (DO ZROBIENIA)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...myTodoTasks.map((task) => _buildTaskSelectionItem(context, ref, task, projectsList, false)),
                    const SizedBox(height: 24),
                  ],

                  if (unassignedActiveTasks.isNotEmpty) ...[
                    Text(
                      'ZADANIA NIEPRZYPISANE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...unassignedActiveTasks.map((task) => _buildTaskSelectionItem(context, ref, task, projectsList, true)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskSelectionItem(
    BuildContext context, 
    WidgetRef ref, 
    ProjectTask task, 
    List<Project> projects,
    bool isUnassigned,
  ) {
    final theme = Theme.of(context);
    final project = projects.firstWhere(
      (p) => p.id == task.projectId, 
      orElse: () => Project(id: '', name: '', description: ''),
    );
    final projectName = project.name.isNotEmpty ? project.name : 'Bez projektu (wrzutka)';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          task.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          projectName,
          style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_arrow_rounded, color: theme.colorScheme.primary, size: 20),
        ),
        onTap: () async {
          Navigator.of(context).pop(); // Close bottom sheet
          
          if (isUnassigned) {
            await ref.read(tasksProvider.notifier).assignTaskToSelf(task);
          }
          
          await ref.read(tasksProvider.notifier).updateTaskStatus(task, 'in_progress');
          ref.invalidate(recentActivityProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rozpoczęto pracę nad zadaniem: ${task.title}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.colorScheme.primary,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _handlePauseTask(BuildContext context, WidgetRef ref, ProjectTask task) async {
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

    if (reason == null || reason.trim().isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
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

    await ref.read(tasksProvider.notifier).updateTaskStatus(task, 'on_hold');
    ref.invalidate(recentActivityProvider);
  }

  Future<void> _handleCompleteTask(BuildContext context, WidgetRef ref, ProjectTask task) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDialog(task: task),
    );

    if (result == null) return;

    final actualHours = result['actualHours'] as double?;
    final completedAt = result['completedAt'] as DateTime?;

    await ref.read(tasksProvider.notifier).updateTaskStatus(
      task, 
      'completed',
      actualHours: actualHours,
      completedAt: completedAt,
    );
    ref.invalidate(recentActivityProvider);
  }

  Future<void> _handleLogTimeTask(BuildContext context, WidgetRef ref, ProjectTask task) async {
    final double? hours = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LogHoursDialog(task: task),
    );

    if (hours == null || hours <= 0) return;

    await ref.read(tasksProvider.notifier).logWorkHours(task, hours);
    ref.invalidate(recentActivityProvider);

    if (context.mounted) {
      final h = hours.toInt();
      final m = ((hours - h) * 60).round();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zadeklarowano ${h}h ${m}m pracy nad zadaniem: ${task.title}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  Widget _buildCompactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    bool isFilled = false,
    required VoidCallback onTap,
  }) {
    final textStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: isFilled ? Colors.white : color,
    );

    return SizedBox(
      height: 34,
      child: isFilled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
