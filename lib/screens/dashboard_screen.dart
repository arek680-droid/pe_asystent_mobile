import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_stats_provider.dart';
import 'task_detail_sheet.dart';

enum ActivityType {
  comment,
  newTask,
}

// Model for recent activity shown in the dashboard feed (combines comments and new tasks)
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

// Provider to fetch and combine recent comments and new tasks into a single feed of 10 items
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

  final List<dynamic> commentsData = commentsResponse as List<dynamic>;
  final List<dynamic> tasksData = tasksResponse as List<dynamic>;

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
                    );
                  },
                  loading: () => const SizedBox(height: 50),
                  error: (err, stack) => const SizedBox(height: 50),
                ),
                const SizedBox(height: 24),

                // 2. Gamification / XP Card
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
                    final completedTasks = tasks.where((t) => t.status == 'completed').length;
                    final totalTasks = tasks.length;
                    final completionPercent = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

                    return Row(
                      children: [
                        // Left: 2x2 Grid of numbers
                        Expanded(
                          flex: 3,
                          child: Column(
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
                                    title: 'Wszystkie',
                                    value: totalTasks.toString(),
                                    icon: Icons.list_rounded,
                                    color: theme.colorScheme.primary,
                                    onTap: onNavigateToTasks,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right: Completion Circular Ring
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 168,
                            padding: const EdgeInsets.all(16),
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
                                  height: 80,
                                  width: 80,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: totalTasks > 0 ? (completedTasks / totalTasks) : 0,
                                        strokeWidth: 8,
                                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                      ),
                                      Text(
                                        '$completionPercent%',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: theme.colorScheme.onSurface,
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
                                    color: isComment
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : Colors.purple.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isComment ? Icons.chat_bubble_outline_rounded : Icons.playlist_add_rounded,
                                    color: isComment ? Colors.blue : Colors.purple,
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
                                                    text: isComment ? ' dodał(a) komentarz:' : ' utworzył(a) zadanie:',
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
          padding: const EdgeInsets.all(16),
          height: 78,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
