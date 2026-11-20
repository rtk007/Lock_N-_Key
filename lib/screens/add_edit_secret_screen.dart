import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/services/secret_service.dart';

class AddEditSecretScreen extends StatefulWidget {
  const AddEditSecretScreen({super.key});

  @override
  State<AddEditSecretScreen> createState() => _AddEditSecretScreenState();
}

class _AddEditSecretScreenState extends State<AddEditSecretScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _shortcutController = TextEditingController();
  final _tagsController = TextEditingController();
  final _notesController = TextEditingController();
  final _backupCodesInputController = TextEditingController();

  String _type = 'API Key';
  final List<String> _types = [
    'API Key',
    'Password',
    'Token',
    'Secret File',
    '2FA Backup Codes',
    'Note',
    'Other',
  ];

  bool _isInit = true;
  bool _isEdit = false;
  String? _existingId;
  DateTime _createdAt = DateTime.now();
  DateTime? _expiryDate;
  bool _obscureValue = true;

  // File Attachment State
  String? _fileName;
  int? _fileSize;
  String? _fileExtension;
  Uint8List? _fileBytes;
  bool _showFileContentPreview = false;

  // 2FA Backup Codes State
  List<Map<String, dynamic>> _backupCodes = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final secret = ModalRoute.of(context)?.settings.arguments as Secret?;
      if (secret != null) {
        _isEdit = true;
        _existingId = secret.id;
        _createdAt = secret.createdAt;
        _nameController.text = secret.name;
        _type = secret.type;
        _valueController.text = secret.value;
        _shortcutController.text = secret.shortcut.replaceFirst('//', '');
        _tagsController.text = secret.tags.join(', ');
        _expiryDate = secret.expiryDate;
        _notesController.text = secret.notes ?? '';
        _fileName = secret.fileName;
        _fileSize = secret.fileSize;
        _fileExtension = secret.fileExtension;

        if (secret.isFile && secret.value.isNotEmpty) {
          try {
            _fileBytes = base64Decode(secret.value);
          } catch (_) {}
        }

        if (secret.isBackupCodes && secret.metadata != null) {
          final rawCodes = secret.metadata!['codes'] as List<dynamic>?;
          if (rawCodes != null) {
            _backupCodes = rawCodes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _shortcutController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _backupCodesInputController.dispose();
    super.dispose();
  }

  // ─── File Picker Logic ───────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data.')),
          );
          return;
        }

        // Limit to 25 MB for optimal performance
        if (bytes.length > 25 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File exceeds 25 MB limit for vault storage.')),
          );
          return;
        }

        setState(() {
          _fileName = file.name;
          _fileSize = bytes.length;
          _fileExtension = file.extension ?? file.name.split('.').last;
          _fileBytes = bytes;
          _valueController.text = base64Encode(bytes);
          if (_nameController.text.isEmpty) {
            _nameController.text = file.name;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _exportFileToDisk() async {
    if (_fileBytes == null && _valueController.text.isNotEmpty) {
      try {
        _fileBytes = base64Decode(_valueController.text);
      } catch (_) {}
    }

    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file content to export.')),
      );
      return;
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Decrypted File',
      fileName: _fileName ?? 'secret_file.bin',
    );

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(_fileBytes!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to: $savePath')),
        );
      }
    }
  }

  // ─── 2FA Backup Codes Logic ──────────────────────────────────────────────
  void _parseBackupCodesFromInput() {
    final raw = _backupCodesInputController.text.trim();
    if (raw.isEmpty) return;

    // Split by newlines, spaces, commas, or semicolons
    final tokens = raw
        .split(RegExp(r'[\r\n\s,;]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 4)
        .toList();

    if (tokens.isEmpty) return;

    setState(() {
      for (final code in tokens) {
        if (!_backupCodes.any((c) => c['code'] == code)) {
          _backupCodes.add({'code': code, 'used': false, 'usedAt': null});
        }
      }
      _backupCodesInputController.clear();
      _syncBackupCodesToValue();
    });
  }

  void _toggleBackupCodeUsed(int index) {
    setState(() {
      final item = _backupCodes[index];
      final wasUsed = item['used'] == true;
      item['used'] = !wasUsed;
      item['usedAt'] = !wasUsed ? DateTime.now().toIso8601String() : null;
      _syncBackupCodesToValue();
    });
  }

  void _syncBackupCodesToValue() {
    // Value stores readable text, metadata stores structured state
    _valueController.text = _backupCodes.map((c) => c['code']).join('\n');
  }

  // ─── Save Action ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    var value = _valueController.text;
    final shortcut = _shortcutController.text.trim();
    final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Validation for files
    if (_type == 'Secret File' && value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or upload a secret file.')),
      );
      return;
    }

    // Validation for 2FA backup codes
    Map<String, dynamic>? metadata;
    if (_type == '2FA Backup Codes') {
      if (_backupCodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one backup code.')),
        );
        return;
      }
      metadata = {'codes': _backupCodes};
    }

    final secret = Secret(
      id: _existingId ?? '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      name: name,
      type: _type,
      value: value,
      shortcut: shortcut.isNotEmpty ? (shortcut.startsWith('//') ? shortcut : '//$shortcut') : '',
      tags: tags,
      expiryDate: _expiryDate,
      createdAt: _createdAt,
      fileName: _fileName,
      fileSize: _fileSize,
      fileExtension: _fileExtension,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      metadata: metadata,
    );

    await SecretService().saveSecret(secret);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Secret updated' : 'Secret created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFile = _type == 'Secret File';
    final isBackupCodes = _type == '2FA Backup Codes';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Secret' : 'Add New Secret'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Core Secret Information
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Secret Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                            decoration: const InputDecoration(
                              labelText: 'Secret Name',
                              hintText: 'e.g. Supabase Service Key, GitHub Backup Codes',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Secret Type Selector
                          DropdownButtonFormField<String>(
                            value: _type,
                            items: _types.map((t) {
                              IconData icon = Icons.key_outlined;
                              if (t == 'Password') icon = Icons.lock_outline;
                              if (t == 'Secret File') icon = Icons.attach_file_outlined;
                              if (t == '2FA Backup Codes') icon = Icons.checklist_outlined;
                              if (t == 'Note') icon = Icons.description_outlined;

                              return DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(icon, size: 20),
                                    const SizedBox(width: 10),
                                    Text(t),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _type = val;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Secret Type',
                              prefixIcon: Icon(Icons.category_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ─── DYNAMIC INPUT BASED ON TYPE ───────────────────
                          if (isFile)
                            _buildSecretFileUploadArea()
                          else if (isBackupCodes)
                            _buildBackupCodesArea()
                          else
                            _buildStandardSecretValueInput(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Developer & Quick Access Metadata Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.terminal_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Developer Shortcuts & Expiry',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Shortcut
                          TextFormField(
                            controller: _shortcutController,
                            decoration: const InputDecoration(
                              labelText: 'CLI & Quick Access Shortcut (Optional)',
                              hintText: 'openai_key or //openai',
                              helperText: 'Use in `locknkey run` (.env: LNK:alias) or `Alt + Space` overlay.',
                              prefixIcon: Icon(Icons.keyboard_command_key),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tags
                          TextFormField(
                            controller: _tagsController,
                            decoration: const InputDecoration(
                              labelText: 'Tags / Environment (Optional)',
                              hintText: 'production, client-acme, database',
                              helperText: 'Comma separated tags for search & grouping.',
                              prefixIcon: Icon(Icons.label_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Developer Notes (Optional)',
                              hintText: 'Internal documentation, rotation instructions...',
                              prefixIcon: Icon(Icons.edit_note_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expiration Presets & Health
                          _buildExpirySection(theme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── WIDGET: Secret File Dropzone & Card ─────────────────────────────────
  Widget _buildSecretFileUploadArea() {
    final theme = Theme.of(context);
    final hasFile = _fileName != null && _fileSize != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasFile)
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Click to Browse or Attach Secret File',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supports .pem, .key, .json, .ovpn, .jks, .env, certs (Encrypted with AES-256-GCM)',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_getFileIcon(_fileExtension), color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatFileSize(_fileSize!)} • ${_fileExtension?.toUpperCase() ?? 'FILE'} • AES-256 Encrypted',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Export/Download Decrypted File',
                      onPressed: _exportFileToDisk,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined),
                      tooltip: 'Replace File',
                      onPressed: _pickFile,
                    ),
                  ],
                ),
                if (_isTextPreviewable(_fileExtension)) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'File Content Preview',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _showFileContentPreview = !_showFileContentPreview),
                        icon: Icon(_showFileContentPreview ? Icons.visibility_off : Icons.visibility, size: 16),
                        label: Text(_showFileContentPreview ? 'Hide Preview' : 'Show Preview'),
                      ),
                    ],
                  ),
                  if (_showFileContentPreview)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _getDecodedTextPreview(),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ─── WIDGET: 2FA Backup Codes Tracker ─────────────────────────────────────
  Widget _buildBackupCodesArea() {
    final theme = Theme.of(context);
    final remainingCount = _backupCodes.where((c) => c['used'] != true).length;
    final totalCount = _backupCodes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counter & Warning Banner
        if (totalCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: remainingCount <= 2 
                  ? Colors.red.withOpacity(0.15) 
                  : theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: remainingCount <= 2 ? Colors.red : theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  remainingCount <= 2 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: remainingCount <= 2 ? Colors.red : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    remainingCount <= 2
                        ? '⚠️ Critical: Only $remainingCount of $totalCount codes remaining! Regenerate 2FA codes soon.'
                        : '$remainingCount of $totalCount backup codes remaining.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: remainingCount <= 2 ? Colors.redAccent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Input paste box
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _backupCodesInputController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Paste Backup Codes',
                  hintText: 'Paste 10-12 codes here (separated by spaces or newlines)...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.paste_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: FilledButton.tonalIcon(
                onPressed: _parseBackupCodesFromInput,
                icon: const Icon(Icons.add),
                label: const Text('Parse'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Interactive Codes Grid
        if (_backupCodes.isNotEmpty) ...[
          Text(
            'Interactive Code List (Click to strike out used codes):',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_backupCodes.length, (index) {
              final item = _backupCodes[index];
              final isUsed = item['used'] == true;
              final code = item['code']?.toString() ?? '';

              return FilterChip(
                selected: isUsed,
                selectedColor: Colors.grey.withOpacity(0.3),
                label: Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    decoration: isUsed ? TextDecoration.lineThrough : null,
                    color: isUsed ? Colors.grey : null,
                  ),
                ),
                avatar: Icon(
                  isUsed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: isUsed ? Colors.green : Colors.grey,
                ),
                onSelected: (_) => _toggleBackupCodeUsed(index),
              );
            }),
          ),
        ],
      ],
    );
  }

  // ─── WIDGET: Standard Secret Value Input ──────────────────────────────────
  Widget _buildStandardSecretValueInput() {
    final isNote = _type == 'Note';

    return TextFormField(
      controller: _valueController,
      obscureText: isNote ? false : _obscureValue,
      validator: (v) => v == null || v.trim().isEmpty ? 'Secret value is required' : null,
      maxLines: isNote ? 4 : 1,
      decoration: InputDecoration(
        labelText: isNote ? 'Secure Note Content' : 'Secret Value',
        helperText: 'Encrypted at rest using AES-256-GCM.',
        prefixIcon: Icon(isNote ? Icons.description_outlined : Icons.lock_outline),
        suffixIcon: !isNote
            ? IconButton(
                icon: Icon(_obscureValue ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureValue = !_obscureValue),
              )
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }

  // ─── WIDGET: Expiration Presets & Date Picker ────────────────────────────
  Widget _buildExpirySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expiration Date (TTL)',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_expiryDate != null)
              Text(
                _getExpirySummaryText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _expiryDate!.isBefore(DateTime.now()) ? Colors.red : Colors.orange,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Preset Chips
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Never'),
              avatar: _expiryDate == null ? const Icon(Icons.check, size: 16) : null,
              onPressed: () => setState(() => _expiryDate = null),
            ),
            ActionChip(
              label: const Text('30 Days'),
              onPressed: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 30))),
            ),
            ActionChip(
              label: const Text('90 Days'),
              onPressed: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 90))),
            ),
            ActionChip(
              label: const Text('1 Year'),
              onPressed: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 365))),
            ),
            ActionChip(
              label: const Text('Custom...'),
              avatar: const Icon(Icons.calendar_today, size: 14),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (date != null) setState(() => _expiryDate = date);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ─── Utility Helpers ──────────────────────────────────────────────────────
  String _getExpirySummaryText() {
    if (_expiryDate == null) return 'No expiry';
    final diff = _expiryDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Expired ${-diff} days ago';
    if (diff == 0) return 'Expires today';
    return 'Expires in $diff days';
  }

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pem':
      case 'key':
      case 'pub':
        return Icons.vpn_key_outlined;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'env':
        return Icons.code_outlined;
      case 'ovpn':
      case 'conf':
        return Icons.security_outlined;
      case 'jks':
      case 'p12':
      case 'keystore':
        return Icons.verified_user_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _isTextPreviewable(String? ext) {
    const textExts = {'json', 'pem', 'key', 'txt', 'env', 'conf', 'ovpn', 'yaml', 'yml', 'md', 'pub'};
    return textExts.contains(ext?.toLowerCase());
  }

  String _getDecodedTextPreview() {
    if (_fileBytes == null) return 'No preview available.';
    try {
      return utf8.decode(_fileBytes!);
    } catch (_) {
      return 'Binary file (cannot be displayed as text).';
    }
  }
}
