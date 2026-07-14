class TodoNote {
  final String id;
  final String userId;
  final String title;
  final bool completed;
  final String priority; // 'low' | 'medium' | 'high'
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int position;

  TodoNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.position,
  });

  factory TodoNote.fromJson(Map<String, dynamic> json) {
    return TodoNote(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      completed: json['completed'] as bool? ?? false,
      priority: json['priority']?.toString() ?? 'medium',
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())! : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())! : DateTime.now(),
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'completed': completed,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'position': position,
    };
  }

  TodoNote copyWith({
    String? id,
    String? userId,
    String? title,
    bool? completed,
    String? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? position,
  }) {
    return TodoNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      position: position ?? this.position,
    );
  }
}
