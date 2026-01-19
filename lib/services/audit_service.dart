import 'package:hive_flutter/hive_flutter.dart';
import 'package:lock_n_key/models/audit_log.dart';
import 'package:lock_n_key/services/auth_service.dart';

class AuditService {
  final AuthService _auth = AuthService();

  Box get _box => _auth.auditBox;

  Future<void> log(String action, String source, {String details = '', String status = 'SUCCESS'}) async {
    final log = AuditLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      action: action,
      source: source,
      details: details,
      status: status,
    );
    await _box.put(log.id, log.toMap());
  }

  List<AuditLog> getRecentLogs({int limit = 20}) {
    final logs = <AuditLog>[];
    for (var key in _box.keys) {
      final data = _box.get(key);
      if (data is Map) {
        try {
          logs.add(AuditLog.fromMap(data));
        } catch (e) {
          // Skip malformed
        }
      }
    }
    // Sort newest first
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    if (limit > 0 && logs.length > limit) {
      return logs.sublist(0, limit);
    }
    return logs;
  }

  // Get activity counts for the last [days] days
  Map<DateTime, int> getDailyActivity(int days) {
    final now = DateTime.now();
    final Map<DateTime, int> activity = {};
    
    // Initialize with 0 in chronological order (past to future)
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      activity[day] = 0;
    }

    final logs = getRecentLogs(limit: -1); // Get all logs
    for (var log in logs) {
      final day = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      if (activity.containsKey(day)) {
        activity[day] = (activity[day] ?? 0) + 1;
      }
    }
    return activity;
  }
}
