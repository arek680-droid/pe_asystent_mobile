class Project {
  final String id;
  final String name;
  final String description;

  Project({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Bez nazwy',
      description: json['description'] as String? ?? '',
    );
  }
}
