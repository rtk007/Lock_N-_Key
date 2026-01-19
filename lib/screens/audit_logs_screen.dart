import 'package:flutter/material.dart';
import 'package:lock_n_key/models/audit_log.dart';
import 'package:lock_n_key/services/audit_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _auditService = AuditService();
  List<AuditLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = _auditService.getRecentLogs(limit: 50); // Get last 50
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Security Audit Logs',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLogs,
                  tooltip: 'Refresh Logs',
                )
              ],
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: double.infinity,
                  child: _logs.isEmpty 
                  ? const Center(child: Text('No audit logs found'))
                  : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Theme.of(context).colorScheme.surface,
                      ),
                      columns: const [
                        DataColumn(label: Text('TIMESTAMP')),
                        DataColumn(label: Text('ACTION')),
                        DataColumn(label: Text('SOURCE')),
                        DataColumn(label: Text('DETAILS')),
                      ],
                      rows: _logs.map((log) {
                        return DataRow(
                          cells: [
                            DataCell(Text(log.timestamp.toString().split('.')[0], style: const TextStyle(fontFamily: 'monospace'))),
                            DataCell(Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(log.source)),
                            DataCell(Text(log.details)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
