
class Secret {
  final String id;
  final String name;
  final String value; // The actual password/secret
  final String type; // Password, API Key, Token, etc.
  final String shortcut;
  final List<String> tags;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final int usageCount;

  Secret({
    required this.id,
    required this.name,
    required this.value,
    this.type = 'Password',
    this.shortcut = '',
    this.tags = const [],
    this.expiryDate,
    required this.createdAt,
    this.usageCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'type': type,
      'shortcut': shortcut,
      'tags': tags,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  factory Secret.fromMap(Map<dynamic, dynamic> map) {
    return Secret(
      id: map['id'] as String,
      name: map['name'] as String,
      value: map['value'] as String,
      type: map['type'] as String? ?? 'Password',
      shortcut: map['shortcut'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      usageCount: map['usageCount'] as int? ?? 0,
    );
  }

  Secret copyWith({
    String? name,
    String? value,
    String? type,
    String? shortcut,
    List<String>? tags,
    DateTime? expiryDate,
    int? usageCount,
  }) {
    return Secret(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
      type: type ?? this.type,
      shortcut: shortcut ?? this.shortcut,
      tags: tags ?? this.tags,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}
