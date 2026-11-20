import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'package:lock_n_key/services/audit_service.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/services/keystroke_service.dart';
import 'package:window_manager/window_manager.dart';

class QuickAccessOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const QuickAccessOverlay({super.key, required this.onClose});

  @override
  State<QuickAccessOverlay> createState() => _QuickAccessOverlayState();
}

class _QuickAccessOverlayState extends State<QuickAccessOverlay> {
  final _secretService = SecretService();
  final _authService = AuthService();
  final _auditService = AuditService();
  final _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Secret> _matches = [];
  Secret? _selectedMatch;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _selectedMatch = null;
        _statusMessage = '';
      });
      return;
    }

    final secrets = _secretService.getAllSecrets();
    final exactShortcut = secrets.where((s) => s.shortcut == query || s.shortcut == '//$query').toList();

    if (exactShortcut.isNotEmpty) {
      setState(() {
        _matches = exactShortcut;
        _selectedMatch = exactShortcut.first;
        _statusMessage = 'Hit Enter to type "${_selectedMatch!.name}"';
      });
    } else {
      final results = secrets
          .where((s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) ||
              s.shortcut.toLowerCase().contains(query.toLowerCase()) ||
              (s.fileName?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .take(5)
          .toList();

      setState(() {
        _matches = results;
        _selectedMatch = results.isNotEmpty ? results.first : null;
        _statusMessage = results.isNotEmpty ? 'Select and hit Enter' : 'No matches';
      });
    }
  }

  Future<void> _executeCopy() async {
    if (_selectedMatch == null) return;

    if (_selectedMatch!.isFile) {
      setState(() {
        _statusMessage = 'File item. Open app to export.';
      });
      return;
    }

    final canAuth = await _authService.authenticateUser(
      context,
      reason: 'Quick Access "${_selectedMatch!.name}"',
    );
    if (!canAuth) return;

    await _secretService.incrementUsage(_selectedMatch!.id);
    await _auditService.log('QUICK_ACCESS', 'Quick Access', details: _selectedMatch!.name);

    String textToType = _selectedMatch!.value;

    // Handle 2FA Backup Codes: Extract first unused code
    if (_selectedMatch!.isBackupCodes && _selectedMatch!.metadata != null) {
      final rawCodes = (_selectedMatch!.metadata!['codes'] as List<dynamic>?) ?? [];
      final unusedIndex = rawCodes.indexWhere((c) => (c as Map)['used'] != true);

      if (unusedIndex != -1) {
        final codeMap = Map<String, dynamic>.from(rawCodes[unusedIndex] as Map);
        textToType = codeMap['code'].toString();

        // Mark as used
        codeMap['used'] = true;
        codeMap['usedAt'] = DateTime.now().toIso8601String();
        rawCodes[unusedIndex] = codeMap;

        final updated = _selectedMatch!.copyWith(metadata: {'codes': rawCodes});
        await _secretService.saveSecret(updated);
      }
    }

    setState(() {
      _statusMessage = 'Typing...';
    });

    try {
      await KeystrokeService.typeText(textToType);
      widget.onClose();
    } catch (e) {
      debugPrint('Failed to type secret: $e');
      setState(() {
        _statusMessage = 'Error injecting text';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 600,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                spreadRadius: 8,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 24, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 20),
                        decoration: InputDecoration(
                          hintText: 'Type shortcut (e.g. //aws) or name...',
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _executeCopy(),
                      ),
                    ),
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.grey),
                      onPressed: () {
                        widget.onClose();
                      },
                      tooltip: 'Back to App',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        widget.onClose();
                        windowManager.hide();
                      },
                      tooltip: 'Close Overlay',
                    ),
                  ],
                ),
              ),
              if (_matches.isNotEmpty) ...[
                const Divider(height: 1),
                ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final secret = _matches[index];
                    final isSelected = _selectedMatch?.id == secret.id;

                    IconData icon = Icons.vpn_key;
                    if (secret.isFile) icon = Icons.attach_file;
                    if (secret.isBackupCodes) icon = Icons.checklist;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedMatch = secret);
                        _executeCopy();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: isSelected ? Colors.blue : Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                secret.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (secret.isBackupCodes) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('2FA', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                              ),
                            ],
                            const SizedBox(width: 12),
                            if (secret.shortcut.isNotEmpty)
                              Text(secret.shortcut, style: const TextStyle(fontFamily: 'monospace', color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
