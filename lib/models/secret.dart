class Secret {
  final String id;
  final String name;
  final String value; // The actual password, token, base64 file data, or raw text
  final String type; // 'Password', 'API Key', 'Token', 'Secret File', '2FA Backup Codes', 'Note', 'Other'
  final String shortcut;
  final List<String> tags;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final int usageCount;

  // New fields for Secret Files & 2FA Backup Codes
  final String? fileName;
  final int? fileSize;
  final String? fileExtension;
  final String? notes;
  final Map<String, dynamic>? metadata;

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
    this.fileName,
    this.fileSize,
    this.fileExtension,
    this.notes,
    this.metadata,
  });

  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);
  
  bool get isExpiringSoon => 
      expiryDate != null && 
      !isExpired && 
      expiryDate!.difference(DateTime.now()).inDays <= 7;

  int get daysUntilExpiry => 
      expiryDate != null ? expiryDate!.difference(DateTime.now()).inDays : 9999;

  bool get isFile => type == 'Secret File' || fileName != null;
  bool get isBackupCodes => type == '2FA Backup Codes';

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
      'fileName': fileName,
      'fileSize': fileSize,
      'fileExtension': fileExtension,
      'notes': notes,
      'metadata': metadata,
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
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      fileExtension: map['fileExtension'] as String?,
      notes: map['notes'] as String?,
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
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
    String? fileName,
    int? fileSize,
    String? fileExtension,
    String? notes,
    Map<String, dynamic>? metadata,
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
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileExtension: fileExtension ?? this.fileExtension,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }
}
