import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_task.dart';
import 'task_detail_sheet.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<EmployeeReport> _reports = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _fetchReportData(_selectedDate);
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Błąd podczas ładowania raportu. Spróbuj ponownie.';
        _isLoading = false;
      });
    }
  }

  Future<List<EmployeeReport>> _fetchReportData(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // 1. Fetch user profiles
    final profilesResponse = await Supabase.instance.client
        .from('user_profiles')
        .select('id, display_name')
        .order('display_name');

    // 2. Fetch comments created on this day (contains status changes and normal comments)
    final commentsResponse = await Supabase.instance.client
        .from('project_task_comments')
        .select('id, comment, created_at, task_id, project_tasks(title), user_id, user_profiles:user_id(display_name)')
        .gte('created_at', startOfDay.toUtc().toIso8601String())
        .lte('created_at', endOfDay.toUtc().toIso8601String())
        .order('created_at', ascending: true);

    // 3. Fetch completed tasks with completion time on this day to calculate hours
    final completedResponse = await Supabase.instance.client
        .from('project_tasks')
        .select('id, title, completed_at, actual_hours, assigned_to, assignee:user_profiles!project_tasks_assigned_to_fkey(display_name)')
        .eq('status', 'completed')
        .gte('completed_at', startOfDay.toUtc().toIso8601String())
        .lte('completed_at', endOfDay.toUtc().toIso8601String());

    final List<dynamic> profilesData = (profilesResponse as List<dynamic>?) ?? [];
    final List<dynamic> commentsData = (commentsResponse as List<dynamic>?) ?? [];
    final List<dynamic> completedData = (completedResponse as List<dynamic>?) ?? [];

    final Map<String, EmployeeReport> reports = {};

    // Initialize report maps for all users from profiles
    for (final profileJson in profilesData) {
      final id = profileJson['id']?.toString() ?? '';
      final name = profileJson['display_name']?.toString() ?? 'Użytkownik';
      reports[id] = EmployeeReport(
        userId: id,
        userName: name,
        activities: [],
        completedTasksCount: 0,
        totalHours: 0.0,
      );
    }

    // Helper to dynamically get or create a report for a user
    EmployeeReport getOrCreateReport(String id, Map<String, dynamic>? profileMap) {
      if (reports.containsKey(id)) {
        return reports[id]!;
      }
      String name = profileMap?['display_name']?.toString() ?? '';
      if (name.isEmpty) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && currentUser.id == id) {
          name = currentUser.email?.split('@')[0] ?? 'Ja';
        } else {
          name = 'Pracownik ($id)';
        }
      }
      final newReport = EmployeeReport(
        userId: id,
        userName: name,
        activities: [],
        completedTasksCount: 0,
        totalHours: 0.0,
      );
      reports[id] = newReport;
      return newReport;
    }

    // Process completed tasks metrics
    for (final taskJson in completedData) {
      final userId = taskJson['assigned_to']?.toString() ?? '';
      if (userId.isEmpty) continue;

      final assigneeProfile = taskJson['assignee'] as Map<String, dynamic>?;
      final report = getOrCreateReport(userId, assigneeProfile);
      report.completedTasksCount++;
    }

    // Process comments as activity entries
    for (final commentJson in commentsData) {
      final userId = commentJson['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;

      final commentProfile = commentJson['user_profiles'] as Map<String, dynamic>?;
      final report = getOrCreateReport(userId, commentProfile);

      final commentText = commentJson['comment']?.toString() ?? '';
      // Parse created_at in local timezone for proper display time
      final createdAtUtc = DateTime.tryParse(commentJson['created_at']?.toString() ?? '') ?? DateTime.now();
      final createdAt = createdAtUtc.toLocal();
      
      final taskMap = commentJson['project_tasks'] as Map<String, dynamic>?;
      final taskTitle = taskMap?['title']?.toString() ?? 'Zadanie';
      final taskId = commentJson['task_id']?.toString() ?? '';

      IconData icon;
      Color color;
      String description;

      if (commentText.startsWith('[STATUS] Zmiana statusu na: ')) {
        final status = commentText.replaceFirst('[STATUS] Zmiana statusu na: ', '');
        description = 'Zmienił status na: $status';
        if (status.contains('W trakcie')) {
          icon = Icons.pending_actions_rounded;
          color = Colors.blue;
        } else if (status.contains('Zakończone')) {
          icon = Icons.check_circle_rounded;
          color = Colors.green;
          
          if (status.contains('Czas pracy:')) {
            final timeMatch = RegExp(r'Czas pracy:\s*(\d+)h\s*(\d+)m').firstMatch(status);
            if (timeMatch != null) {
              final h = double.tryParse(timeMatch.group(1) ?? '0') ?? 0.0;
              final m = double.tryParse(timeMatch.group(2) ?? '0') ?? 0.0;
              report.totalHours += h + (m / 60.0);
            }
          }
        } else if (status.contains('Do akceptacji')) {
          icon = Icons.fact_check_rounded;
          color = Colors.purple;
        } else if (status.contains('Wstrzymano')) {
          icon = Icons.pause_circle_filled_rounded;
          color = Colors.orange;
        } else {
          icon = Icons.radio_button_unchecked;
          color = Colors.grey;
        }
      } else if (commentText.startsWith('[LOG] Dodano czas pracy: ')) {
        final timePart = commentText.replaceFirst('[LOG] Dodano czas pracy: ', '').split(' (').first;
        description = 'Zadeklarował czas pracy: $timePart';
        icon = Icons.more_time_rounded;
        color = Colors.blue.shade800;

        final match = RegExp(r'(\d+)h\s*(\d+)m').firstMatch(timePart);
        if (match != null) {
          final h = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          final m = double.tryParse(match.group(2) ?? '0') ?? 0.0;
          report.totalHours += h + (m / 60.0);
        }
      } else if (commentText.startsWith('[WSTRZYMANO] ')) {
        final reason = commentText.replaceFirst('[WSTRZYMANO] ', '');
        description = 'Wstrzymał zadanie (Powód: $reason)';
        icon = Icons.pause_circle_filled_rounded;
        color = Colors.orange;
      } else {
        description = 'Dodał komentarz: "$commentText"';
        icon = Icons.comment_rounded;
        color = Colors.blue.shade300;
      }

      // Format time in Polish local time
      final timeStr = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

      report.activities.add(ReportActivity(
        time: createdAt,
        timeString: timeStr,
        taskId: taskId,
        taskTitle: taskTitle,
        description: description,
        icon: icon,
        color: color,
      ));
    }

    // Sort activities chronologically
    for (final report in reports.values) {
      report.activities.sort((a, b) => a.time.compareTo(b.time));
    }

    return reports.values.toList();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadReport();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  String _formatPolishDate(DateTime date) {
    const weekdays = [
      'Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'
    ];
    const months = [
      'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
      'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'
    ];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final comparisonDate = DateTime(date.year, date.month, date.day);
    
    if (comparisonDate == today) {
      return 'Dzisiaj, ${date.day} $month';
    } else if (comparisonDate == today.subtract(const Duration(days: 1))) {
      return 'Wczoraj, ${date.day} $month';
    } else if (comparisonDate == today.add(const Duration(days: 1))) {
      return 'Jutro, ${date.day} $month';
    }
    
    return '$weekday, ${date.day} $month';
  }

  String _getInitials(String displayName) {
    if (displayName.trim().isEmpty) return '?';
    final parts = displayName.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _getAvatarBgColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> colors = [
      Colors.blue.shade300,
      Colors.green.shade300,
      Colors.orange.shade300,
      Colors.purple.shade300,
      Colors.pink.shade300,
      Colors.teal.shade300,
      Colors.indigo.shade300,
      Colors.cyan.shade300,
    ];
    return colors[hash % colors.length];
  }

  Future<void> _openTaskDetails(BuildContext context, String taskId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final response = await Supabase.instance.client
          .from('project_tasks')
          .select()
          .eq('id', taskId)
          .single();
      
      if (context.mounted) Navigator.of(context).pop();
      
      final task = ProjectTask.fromJson(response);
      
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TaskDetailSheet(task: task),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się załadować szczegółów zadania')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calculate total statistics for this day
    final totalCompleted = _reports.fold(0, (sum, r) => sum + r.completedTasksCount);
    final totalHours = _reports.fold(0.0, (sum, r) => sum + r.totalHours);

    // Filter employees with any activity
    final activeReports = _reports.where((r) => r.activities.isNotEmpty).toList();
    final inactiveReports = _reports.where((r) => r.activities.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dzienny Raport Pracy',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: Column(
          children: [
            // Date Selector Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: () => _changeDate(-1),
                  ),
                  TextButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.primary),
                    label: Text(
                      _formatPolishDate(_selectedDate),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadReport,
                                child: const Text('Ponów'),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Summary Cards
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        context,
                                        'Zrealizowane zadania',
                                        '$totalCompleted',
                                        Icons.task_alt_rounded,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildMetricCard(
                                        context,
                                        'Czas pracy (suma)',
                                        '${totalHours.toStringAsFixed(1)}h',
                                        Icons.access_time_filled_rounded,
                                        Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Active Employees Section
                            if (activeReports.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                                  child: Text(
                                    'AKTYWNI PRACOWNICY',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final report = activeReports[index];
                                    return Column(
                                      children: [
                                        _buildSlackStyleEmployeeBlock(context, report),
                                        if (index < activeReports.length - 1)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: Divider(
                                              height: 1,
                                              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                  childCount: activeReports.length,
                                ),
                              ),
                            ],

                            // Inactive Employees Section
                            if (inactiveReports.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                                  child: Text(
                                    'BRAK AKTYWNOŚCI W TYM DNIU',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: inactiveReports.map((report) {
                                      final initials = _getInitials(report.userName);
                                      final avatarColor = _getAvatarBgColor(report.userName);
                                      return Chip(
                                        avatar: CircleAvatar(
                                          backgroundColor: avatarColor,
                                          child: Text(
                                            initials,
                                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        label: Text(
                                          report.userName,
                                          style: GoogleFonts.inter(fontSize: 12),
                                        ),
                                        backgroundColor: theme.colorScheme.surface,
                                        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],

                            // Empty Screen fallback if no users at all
                            if (_reports.isEmpty)
                              const SliverFillRemaining(
                                child: Center(
                                  child: Text('Brak zdefiniowanych pracowników w systemie.'),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.1)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlackStyleEmployeeBlock(BuildContext context, EmployeeReport report) {
    final theme = Theme.of(context);
    final avatarColor = _getAvatarBgColor(report.userName);
    final initials = _getInitials(report.userName);

    // Group activities by task ID to form a clean list
    final Map<String, TaskActivitySummary> taskSummaries = {};
    for (final act in report.activities) {
      if (!taskSummaries.containsKey(act.taskId)) {
        taskSummaries[act.taskId] = TaskActivitySummary(
          taskId: act.taskId,
          taskTitle: act.taskTitle,
          latestTime: act.time,
        );
      }
      
      final summary = taskSummaries[act.taskId]!;
      if (act.time.isAfter(summary.latestTime)) {
        summary.latestTime = act.time;
      }

      if (act.description.startsWith('Zadeklarował czas pracy: ')) {
        final timePart = act.description.replaceFirst('Zadeklarował czas pracy: ', '');
        final match = RegExp(r'(\d+)h\s*(\d+)m').firstMatch(timePart);
        if (match != null) {
          final h = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          final m = double.tryParse(match.group(2) ?? '0') ?? 0.0;
          summary.loggedHours += h + (m / 60.0);
        }
      } else if (act.description.contains('Czas pracy:')) {
        final match = RegExp(r'Czas pracy:\s*(\d+)h\s*(\d+)m').firstMatch(act.description);
        if (match != null) {
          final h = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          final m = double.tryParse(match.group(2) ?? '0') ?? 0.0;
          summary.loggedHours += h + (m / 60.0);
        }
      }

      if (act.description.startsWith('Zmienił status na: ')) {
        final status = act.description.replaceFirst('Zmienił status na: ', '').toLowerCase();
        summary.status = status;
      } else if (act.description.startsWith('Wstrzymał zadanie (Powód: ')) {
        final reason = act.description.replaceFirst('Wstrzymał zadanie (Powód: ', '').replaceAll(')', '');
        summary.status = 'wstrzymano ($reason)';
      } else if (act.description.startsWith('Dodał komentarz: "')) {
        final commentVal = act.description.replaceFirst('Dodał komentarz: "', '').replaceAll('"', '');
        summary.comment = commentVal;
      }
    }

    final summariesList = taskSummaries.values.toList()
      ..sort((a, b) => b.latestTime.compareTo(a.latestTime)); // sort by latest activity

    final timeStr = summariesList.isNotEmpty 
        ? '${summariesList.first.latestTime.hour.toString().padLeft(2, '0')}:${summariesList.first.latestTime.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: avatarColor,
            radius: 20,
            child: Text(
              initials,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      report.userName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ...List.generate(summariesList.length, (index) {
                  final summary = summariesList[index];
                  
                  String statusText = '';
                  Color statusColor = theme.colorScheme.secondary.withValues(alpha: 0.8);
                  
                  if (summary.status != null) {
                    statusText = ' - ${summary.status}';
                    if (summary.status!.contains('zakończone')) {
                      statusColor = Colors.green.shade600;
                    } else if (summary.status!.contains('w trakcie')) {
                      statusColor = Colors.blue.shade600;
                    } else if (summary.status!.contains('wstrzymano')) {
                      statusColor = Colors.orange.shade600;
                    } else if (summary.status!.contains('do akceptacji')) {
                      statusColor = Colors.purple.shade600;
                    }
                  } else if (summary.comment != null) {
                    statusText = ' - skomentowano: "${summary.comment}"';
                    statusColor = theme.colorScheme.secondary.withValues(alpha: 0.6);
                  }

                  String timeLoggedText = '';
                  if (summary.loggedHours > 0) {
                    final h = summary.loggedHours.toInt();
                    final m = ((summary.loggedHours - h) * 60).round();
                    timeLoggedText = ' (${h}h ${m}m)';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyLarge?.color,
                              ),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => _openTaskDetails(context, summary.taskId),
                                    child: Text(
                                      summary.taskTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                TextSpan(
                                  text: statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: summary.status != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (timeLoggedText.isNotEmpty)
                                  TextSpan(
                                    text: timeLoggedText,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeReport {
  final String userId;
  final String userName;
  final List<ReportActivity> activities;
  int completedTasksCount;
  double totalHours;

  EmployeeReport({
    required this.userId,
    required this.userName,
    required this.activities,
    required this.completedTasksCount,
    required this.totalHours,
  });
}

class ReportActivity {
  final DateTime time;
  final String timeString;
  final String taskId;
  final String taskTitle;
  final String description;
  final IconData icon;
  final Color color;

  ReportActivity({
    required this.time,
    required this.timeString,
    required this.taskId,
    required this.taskTitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class TaskActivitySummary {
  final String taskId;
  final String taskTitle;
  DateTime latestTime;
  String? status;
  String? comment;
  double loggedHours;

  TaskActivitySummary({
    required this.taskId,
    required this.taskTitle,
    required this.latestTime,
    this.status,
    this.comment,
    this.loggedHours = 0.0,
  });
}
