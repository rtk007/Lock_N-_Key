import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'package:lock_n_key/services/audit_service.dart';

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
    if (_searchQuery.isEmpty) return _secrets;
    return _secrets.where((s) => 
      s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      s.shortcut.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'My Secrets',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search secrets...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.addSecret);
                    _loadSecrets();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Secret'),
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _secrets.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('No secrets found', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Create one ensuring you are safe.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filteredSecrets.length,
                  itemBuilder: (context, index) {
                    final secret = _filteredSecrets[index];
                    final isExpired = secret.expiryDate != null && secret.expiryDate!.isBefore(DateTime.now());
                    final status = isExpired ? 'EXPIRED' : 'ACTIVE';
                    final statusColor = isExpired ? Colors.red : Colors.green;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0), // Added padding for better layout with tags
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.vpn_key_outlined),
                              ),
                              title: Row(
                                children: [
                                  Text(secret.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: statusColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (secret.shortcut.isNotEmpty)
                                    Text(secret.shortcut, style: const TextStyle(fontFamily: 'monospace')),
                                  if (secret.expiryDate != null)
                                    Text(
                                      'Expires: ${secret.expiryDate.toString().split(' ')[0]}',
                                      style: TextStyle(fontSize: 12, color: isExpired ? Colors.red : Colors.grey),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                    onPressed: () => _handleEdit(secret),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () => _handleDelete(secret),
                                  ),
                                ],
                              ),
                            ),
                            if (secret.tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              child: SizedBox(
                                height: 32,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: secret.tags.map((tag) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Chip(
                                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
