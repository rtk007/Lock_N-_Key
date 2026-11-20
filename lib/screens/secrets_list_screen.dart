import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'package:lock_n_key/services/audit_service.dart';
import 'package:lock_n_key/widgets/secure_file_viewer_dialog.dart';

class SecretsListScreen extends StatefulWidget {
  const SecretsListScreen({super.key});

  @override
  State<SecretsListScreen> createState() => _SecretsListScreenState();
}

class _SecretsListScreenState extends State<SecretsListScreen> {
  final _secretService = SecretService();
  final _auditService = AuditService();
  final _authService = AuthService();
  List<Secret> _secrets = [];
  String _searchQuery = '';
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'API Keys & Passwords',
    'Secret Files',
    '2FA Backup Codes',
    'Expiring / Expired',
  ];

  @override
  void initState() {
    super.initState();
    _loadSecrets();
  }

  void _loadSecrets() {
    setState(() {
      _secrets = _secretService.getAllSecrets();
    });
  }

  List<Secret> get _filteredSecrets {
    return _secrets.where((s) {
      // 1. Text Search Filter
      final matchesQuery = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.shortcut.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.fileName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          s.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));

      if (!matchesQuery) return false;

      // 2. Category Filter
      switch (_activeFilter) {
        case 'Secret Files':
          return s.isFile;
        case '2FA Backup Codes':
          return s.isBackupCodes;
        case 'API Keys & Passwords':
          return !s.isFile && !s.isBackupCodes;
        case 'Expiring / Expired':
          return s.isExpired || s.isExpiringSoon;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _handleDelete(Secret secret) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Secret?'),
        content: Text('Are you sure you want to delete "${secret.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _secretService.deleteSecret(secret.id);
      await _auditService.log('DELETE_SECRET', 'Secrets List', details: secret.name);
      _loadSecrets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret deleted')),
        );
      }
    }
  }

  Future<void> _handleEdit(Secret secret) async {
    final authenticated = await _authService.authenticateUser(
      context,
      reason: 'Authenticate to edit this secret',
    );

    if (authenticated && mounted) {
      await Navigator.pushNamed(context, AppRoutes.addSecret, arguments: secret);
      _loadSecrets();
    }
  }

  Future<void> _handleViewFile(Secret secret) async {
    final authenticated = await _authService.authenticateUser(
      context,
      reason: 'Authenticate to view "${secret.fileName ?? secret.name}"',
    );

    if (authenticated && mounted) {
      await SecureFileViewerDialog.show(context, secret);
    }
  }

  Future<void> _handleExportFile(Secret secret) async {
    if (!secret.isFile || secret.value.isEmpty) return;

    final authenticated = await _authService.authenticateUser(
      context,
      reason: 'Authenticate to export "${secret.fileName}"',
    );
    if (!authenticated || !mounted) return;

    try {
      final bytes = base64Decode(secret.value);
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Decrypted File',
        fileName: secret.fileName ?? 'secret_file.bin',
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header & Search
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'My Secrets',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name, shortcut, tag...',
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, AppRoutes.addSecret);
                        _loadSecrets();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New Secret'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _activeFilter == filter;
                      int count = 0;
                      if (filter == 'All') {
                        count = _secrets.length;
                      } else if (filter == 'Secret Files') {
                        count = _secrets.where((s) => s.isFile).length;
                      } else if (filter == '2FA Backup Codes') {
                        count = _secrets.where((s) => s.isBackupCodes).length;
                      } else if (filter == 'API Keys & Passwords') {
                        count = _secrets.where((s) => !s.isFile && !s.isBackupCodes).length;
                      } else if (filter == 'Expiring / Expired') {
                        count = _secrets.where((s) => s.isExpired || s.isExpiringSoon).length;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text('$filter ($count)'),
                          onSelected: (_) => setState(() => _activeFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List Content
          Expanded(
            child: _filteredSecrets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No secrets in this category' : 'No matching secrets found',
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "New Secret" to store API keys, files, or backup codes.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredSecrets.length,
                    itemBuilder: (context, index) {
                      final secret = _filteredSecrets[index];
                      return _buildSecretTile(secret, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretTile(Secret secret, ThemeData theme) {
    Color statusColor = Colors.green;
    String status = 'ACTIVE';

    if (secret.isExpired) {
      status = 'EXPIRED';
      statusColor = Colors.red;
    } else if (secret.isExpiringSoon) {
      status = 'EXPIRING (${secret.daysUntilExpiry}d)';
      statusColor = Colors.orange;
    }

    // Determine Icon
    IconData iconData = Icons.vpn_key_outlined;
    if (secret.isFile) {
      iconData = Icons.attach_file_outlined;
    } else if (secret.isBackupCodes) {
      iconData = Icons.checklist_outlined;
    } else if (secret.type == 'Password') {
      iconData = Icons.lock_outline;
    }

    // 2FA Backup codes metadata helper
    String? backupCodesInfo;
    if (secret.isBackupCodes && secret.metadata != null) {
      final codes = (secret.metadata!['codes'] as List<dynamic>?) ?? [];
      final remaining = codes.where((c) => (c as Map)['used'] != true).length;
      backupCodesInfo = '$remaining / ${codes.length} remaining';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              onTap: () => secret.isFile ? _handleViewFile(secret) : _handleEdit(secret),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: theme.colorScheme.primary),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      secret.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),

                  // 2FA Backup count pill
                  if (backupCodesInfo != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.4)),
                      ),
                      child: Text(
                        backupCodesInfo,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (secret.isFile)
                    Text(
                      '${secret.fileName ?? 'File'} • ${_formatBytes(secret.fileSize ?? 0)} • ${secret.fileExtension?.toUpperCase() ?? 'ENC'} • Tap to View',
                      style: TextStyle(color: Colors.cyanAccent.withOpacity(0.8), fontSize: 12),
                    )
                  else if (secret.shortcut.isNotEmpty)
                    Text(
                      'Shortcut: ${secret.shortcut}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  if (secret.expiryDate != null)
                    Text(
                      'Expires: ${secret.expiryDate.toString().split(' ')[0]}',
                      style: TextStyle(fontSize: 11, color: secret.isExpired ? Colors.red : Colors.grey[500]),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (secret.isFile) ...[
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: Colors.cyanAccent),
                      tooltip: 'View File (In-Memory, No Disk)',
                      onPressed: () => _handleViewFile(secret),
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined),
                      tooltip: 'Export to Disk (Optional)',
                      onPressed: () => _handleExportFile(secret),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit / Details',
                    onPressed: () => _handleEdit(secret),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete',
                    onPressed: () => _handleDelete(secret),
                  ),
                ],
              ),
            ),

            // Tags row
            if (secret.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: SizedBox(
                  height: 24,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: secret.tags
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text(t, style: const TextStyle(fontSize: 9)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
