class ProjectTask {
  final String id;
  final String projectId;
  final String? milestoneId;
  final String title;
  final String description;
  final String status; // 'todo' | 'in_progress' | 'completed' | 'on_hold' | 'to_accept'
  final String priority; // 'low' | 'medium' | 'high' | 'critical'
  final String? assignedTo;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double estimatedHours;
  final double actualHours;

  ProjectTask({
    required this.id,
    required this.projectId,
    this.milestoneId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.startDate,
    this.dueDate,
    this.completedAt,
    required this.estimatedHours,
    required this.actualHours,
  });

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      milestoneId: json['milestone_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'medium',
      assignedTo: json['assigned_to'] as String?,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'milestone_id': milestoneId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assigned_to': assignedTo,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
    };
  }

  ProjectTask copyWith({
    String? id,
    String? projectId,
    String? milestoneId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assignedTo,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedAt,
    double? estimatedHours,
    double? actualHours,
  }) {
    return ProjectTask(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      milestoneId: milestoneId ?? this.milestoneId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
    );
  }
}
