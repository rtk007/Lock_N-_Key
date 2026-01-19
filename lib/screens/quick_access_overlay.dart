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
    // Prioritize exact shortcut match first
    final exactShortcut = secrets.where((s) => s.shortcut == query || s.shortcut == '//$query').toList();
    
    if (exactShortcut.isNotEmpty) {
      // Auto-select the first exact match
      setState(() {
        _matches = exactShortcut;
        _selectedMatch = exactShortcut.first;
        _statusMessage = 'Hit Enter to copy "${_selectedMatch!.name}"';
      });
    } else {
      // Fuzzy search
      final results = secrets.where((s) => 
        s.name.toLowerCase().contains(query.toLowerCase()) || 
        s.shortcut.toLowerCase().contains(query.toLowerCase())
      ).take(5).toList();
      
      setState(() {
        _matches = results;
        _selectedMatch = results.isNotEmpty ? results.first : null;
        _statusMessage = results.isNotEmpty ? 'Select and hit Enter' : 'No matches';
      });
    }
  }



  Future<void> _executeCopy() async {
    if (_selectedMatch == null) return;
    
    // Authenticate
    final canAuth = await _authService.authenticateUser(context, reason: 'Quick Access "${_selectedMatch!.name}"');
    if (!canAuth) return;

    await _secretService.incrementUsage(_selectedMatch!.id);
    await _auditService.log('QUICK_ACCESS', 'Quick Access', details: _selectedMatch!.name);

    setState(() {
      _statusMessage = 'Typing...';
    });

    // Inject Keystrokes via Native C++ Layer
    // This allows zero-clipboard usage and works with any active window
    try {
      await KeystrokeService.typeText(_selectedMatch!.value);
      // Window is automatically hidden by C++ layer
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
                          color: _statusMessage == 'Copied!' ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage, 
                          style: TextStyle(
                            color: _statusMessage == 'Copied!' ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.grey),
                      onPressed: () {
                         widget.onClose();
                         // Do not hide window, just return to app
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
                            Icon(Icons.vpn_key, size: 16, color: isSelected ? Colors.blue : Colors.grey),
                            const SizedBox(width: 12),
                            Text(secret.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            const Spacer(),
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
