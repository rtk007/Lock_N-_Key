
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String action; // e.g., 'ACCESS_SECRET', 'LOGIN', 'CREATE_SECRET'
  final String source; // e.g., 'Google Key', 'System'
  final String details;
  final String status; // 'SUCCESS', 'FAILURE'

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.source,
    this.details = '',
    this.status = 'SUCCESS',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action,
      'source': source,
      'details': details,
      'status': status,
    };
  }

  factory AuditLog.fromMap(Map<dynamic, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      action: map['action'] as String,
      source: map['source'] as String,
      details: map['details'] as String? ?? '',
      status: map['status'] as String? ?? 'SUCCESS',
    );
  }
}
