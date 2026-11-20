import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lock_n_key/models/audit_log.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/audit_service.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

// Feature screens
import 'package:lock_n_key/screens/secrets_list_screen.dart';
import 'package:lock_n_key/screens/audit_logs_screen.dart';
import 'package:lock_n_key/screens/settings_screen.dart';
import 'package:lock_n_key/screens/about_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Services
  final _secretService = SecretService();
  final _auditService = AuditService();
  final _authService = AuthService();

  // State
  int _selectedIndex = 0;
  String _userName = 'Developer';

  // Dashboard Data
  List<Secret> _secrets = [];
  Secret? _mostUsedSecret;
  List<AuditLog> _recentLogs = [];
  Map<DateTime, int> _activityData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await _authService.getUserName();
    final secrets = _secretService.getAllSecrets();
    final mostUsed = _secretService.getMostUsedSecret();
    final logs = _auditService.getRecentLogs(limit: 5);
    final activity = _auditService.getDailyActivity(7);

    if (mounted) {
      setState(() {
        _userName = name ?? 'User';
        _secrets = secrets;
        _mostUsedSecret = mostUsed;
        _recentLogs = logs;
        _activityData = activity;
        _isLoading = false;
      });
    }
  }

  Future<void> _showExtensionInstallationDialog() async {
    String extensionPath;
    if (kReleaseMode) {
      final exeDir = File(Platform.resolvedExecutable).parent;
      extensionPath = p.join(exeDir.path, 'extension');
    } else {
      extensionPath = 'd:\\lock_n_key\\extension';
    }
    final dir = Directory(extensionPath);

    if (!await dir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extension folder not found!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install Browser Extension'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Open your browser extensions page:\n   • Chrome: chrome://extensions\n   • Edge: edge://extensions'),
            const SizedBox(height: 8),
            const Text('2. Enable "Developer Mode" (top right).'),
            const SizedBox(height: 8),
            const Text('3. Click "Load Unpacked" button.'),
            const SizedBox(height: 8),
            const Text('4. Select the detected extension folder below:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(child: SelectableText(extensionPath, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: extensionPath));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Path copied!')));
                    },
                    tooltip: 'Copy Path',
                  )
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Process.run('explorer.exe', [extensionPath]);
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Folder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildContent(_selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        if (index == 5) {
          _authService.logout().then((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.welcome);
          });
          return;
        }
        setState(() {
          _selectedIndex = index;
          if (index == 0) _loadData();
        });
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: Column(
        children: [
          const SizedBox(height: 24),
          Image.asset('assets/images/logo.png', height: 48),
          const SizedBox(height: 8),
          Text('VAULT',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 32),
        ],
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
        NavigationRailDestination(icon: Icon(Icons.vpn_key_outlined), selectedIcon: Icon(Icons.vpn_key), label: Text('Secrets')),
        NavigationRailDestination(icon: Icon(Icons.history_edu_outlined), selectedIcon: Icon(Icons.history_edu), label: Text('Audit')),
        NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
        NavigationRailDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: Text('About')),
        NavigationRailDestination(icon: Icon(Icons.logout, color: Colors.redAccent), label: Text('Logout', style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return _buildOverview(context);
      case 1:
        return const SecretsListScreen();
      case 2:
        return const AuditLogsScreen();
      case 3:
        return const SettingsScreen();
      case 4:
        return const AboutScreen();
      default:
        return const Center(child: Text('Not found'));
    }
  }

  Widget _buildOverview(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final totalCount = _secrets.length;
    final fileCount = _secrets.where((s) => s.isFile).length;
    final backupCodesCount = _secrets.where((s) => s.isBackupCodes).length;
    final expiredCount = _secrets.where((s) => s.isExpired).length;
    final expiringSoonCount = _secrets.where((s) => s.isExpiringSoon).length;

    // Vault Health Score (0 - 100%)
    int healthScore = 100;
    if (totalCount > 0) {
      healthScore = (100 - (expiredCount * 25) - (expiringSoonCount * 10)).clamp(10, 100);
    }
    Color healthColor = Colors.green;
    if (healthScore < 60) {
      healthColor = Colors.red;
    } else if (healthScore < 85) {
      healthColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: ListView(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good Afternoon, $_userName', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Your offline zero-trust vault status', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, AppRoutes.addSecret);
                      _loadData();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Secret'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showExtensionInstallationDialog,
                    icon: const Icon(Icons.extension_outlined),
                    label: const Text('Extension'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Expiration & Health Alert Banner (if any expired or expiring soon)
          if (expiredCount > 0 || expiringSoonCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: expiredCount > 0 ? Colors.red.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: expiredCount > 0 ? Colors.red.withOpacity(0.4) : Colors.orange.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    expiredCount > 0 ? Icons.error_outline : Icons.warning_amber_rounded,
                    color: expiredCount > 0 ? Colors.redAccent : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      expiredCount > 0
                          ? '⚠️ Vault Alert: $expiredCount secret${expiredCount > 1 ? "s have" : " has"} expired and $expiringSoonCount expiring soon.'
                          : '⏳ Vault Notice: $expiringSoonCount secret${expiringSoonCount > 1 ? "s are" : " is"} expiring within the next 7 days.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: expiredCount > 0 ? Colors.redAccent : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 1; // Switch to secrets list
                      });
                    },
                    child: const Text('Review Now'),
                  ),
                ],
              ),
            ),

          // KPIs (4 Cards)
          Row(
            children: [
              _buildStatCard(
                context,
                'Total Items',
                totalCount.toString(),
                Icons.lock_outline,
                Theme.of(context).colorScheme.primary,
                subtitle: '$fileCount files • $backupCodesCount 2FA lists',
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                'Secret Files',
                fileCount.toString(),
                Icons.attach_file_outlined,
                Colors.cyan,
                subtitle: 'AES-256 encrypted blobs',
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                '2FA Backup Lists',
                backupCodesCount.toString(),
                Icons.checklist_outlined,
                Colors.purpleAccent,
                subtitle: 'Tracking recovery codes',
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                'Vault Health',
                '$healthScore%',
                Icons.health_and_safety_outlined,
                healthColor,
                subtitle: expiredCount == 0 ? 'All credentials healthy' : '$expiredCount expired',
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Graphs & Recent Activity
          SizedBox(
            height: 380,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Graph
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).dividerColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weekly Activity', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= _activityData.length) return const SizedBox();
                                        final date = _activityData.keys.elementAt(index);
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('${date.day}/${date.month}',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _activityData.values.toList().asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.toDouble(),
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 16,
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Recent Activity List
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).dividerColor)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Vault Activity', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _recentLogs.isEmpty
                                ? const Center(child: Text('No activity yet', style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                                    itemCount: _recentLogs.length,
                                    itemBuilder: (context, index) {
                                      final log = _recentLogs[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: _getIconForAction(log.action),
                                        ),
                                        title: Text(log.action,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                            log.details.isNotEmpty ? log.details : log.source,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11)),
                                        trailing: Text(
                                          _formatTime(log.timestamp),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.85)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Icon _getIconForAction(String action) {
    switch (action) {
      case 'VIEW_SECRET':
        return const Icon(Icons.visibility, size: 16, color: Colors.blue);
      case 'COPY_SECRET':
        return const Icon(Icons.copy, size: 16, color: Colors.orange);
      case 'DELETE_SECRET':
        return const Icon(Icons.delete, size: 16, color: Colors.red);
      case 'LOGIN':
        return const Icon(Icons.login, size: 16, color: Colors.green);
      default:
        return const Icon(Icons.history, size: 16, color: Colors.grey);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}';
  }
}
