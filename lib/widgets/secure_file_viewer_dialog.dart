import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lock_n_key/models/secret.dart';

class SecureFileViewerDialog extends StatefulWidget {
  final Secret secret;

  const SecureFileViewerDialog({super.key, required this.secret});

  static Future<void> show(BuildContext context, Secret secret) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SecureFileViewerDialog(secret: secret),
    );
  }

  @override
  State<SecureFileViewerDialog> createState() => _SecureFileViewerDialogState();
}

class _SecureFileViewerDialogState extends State<SecureFileViewerDialog> {
  Uint8List? _fileBytes;
  String? _textContent;
  bool _isImage = false;
  bool _isText = false;
  bool _wrapLines = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _sha256Hash = '';

  @override
  void initState() {
    super.initState();
    _decodeFileContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _decodeFileContent() {
    final value = widget.secret.value;
    if (value.isEmpty) return;

    try {
      _fileBytes = base64Decode(value);
      _sha256Hash = sha256.convert(_fileBytes!).toString();
    } catch (_) {
      // If not base64, assume raw text
      _fileBytes = Uint8List.fromList(utf8.encode(value));
      _sha256Hash = sha256.convert(_fileBytes!).toString();
    }

    final ext = (widget.secret.fileExtension ?? '').toLowerCase();
    const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

    if (imageExtensions.contains(ext)) {
      _isImage = true;
    } else {
      // Try decoding text
      try {
        final decoded = utf8.decode(_fileBytes!);
        // If it's JSON, pretty print it
        if (ext == 'json') {
          try {
            final jsonObj = jsonDecode(decoded);
            _textContent = const JsonEncoder.withIndent('  ').convert(jsonObj);
          } catch (_) {
            _textContent = decoded;
          }
        } else {
          _textContent = decoded;
        }
        _isText = true;
      } catch (_) {
        _isText = false;
      }
    }
  }

  Future<void> _exportToDisk() async {
    if (_fileBytes == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Export Decrypted File?'),
          ],
        ),
        content: const Text(
          'Exporting will write this file to your disk unencrypted.\n\n'
          'Remember to delete the unencrypted copy when you are finished using it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONTINUE EXPORT'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Decrypted File',
      fileName: widget.secret.fileName ?? 'secret_file.bin',
    );

    if (savePath != null) {
      final file = File(savePath);
      await file.writeAsBytes(_fileBytes!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $savePath')),
        );
      }
    }
  }

  void _copyContent() {
    if (_textContent == null) return;
    Clipboard.setData(ClipboardData(text: _textContent!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File content copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = widget.secret.fileName ?? widget.secret.name;
    final ext = widget.secret.fileExtension?.toUpperCase() ?? 'FILE';
    final fileSizeStr = _formatBytes(widget.secret.fileSize ?? (_fileBytes?.length ?? 0));

    return Dialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1000,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getFileIcon(widget.secret.fileExtension), color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 12, color: Colors.greenAccent),
                                SizedBox(width: 4),
                                Text(
                                  'In-Memory Only',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$fileSizeStr • $ext Format • SHA-256: ${_sha256Hash.substring(0, 16)}...',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (_isText) ...[
                  IconButton(
                    icon: Icon(_wrapLines ? Icons.wrap_text : Icons.notes),
                    tooltip: _wrapLines ? 'Disable Line Wrap' : 'Enable Line Wrap',
                    onPressed: () => setState(() => _wrapLines = !_wrapLines),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy File Text',
                    onPressed: _copyContent,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export File to Disk (Optional)',
                  onPressed: _exportToDisk,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close Viewer',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search bar for text files
            if (_isText) ...[
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search in file...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],

            const Divider(height: 1),

            // ─── Main Content Viewer ──────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildViewerContent(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerContent(ThemeData theme) {
    if (_isImage && _fileBytes != null) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _fileBytes!,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const Text('Could not render image preview.'),
          ),
        ),
      );
    }

    if (_isText && _textContent != null) {
      final lines = _textContent!.split('\n');

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers gutter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  lines.length,
                  (i) => Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Code / Text View
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              scrollDirection: _wrapLines ? Axis.vertical : Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  children: _buildHighlightedText(lines),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Binary / Keystore / Unknown formats
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_clock_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          const Text(
            'Binary Protected File',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'This file format cannot be rendered as text or an image.\n'
            'It is stored safely in your vault with AES-256-GCM encryption.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHA-256 Checksum:', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 4),
                SelectableText(
                  _sha256Hash,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.cyanAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exportToDisk,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export File to Disk'),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightedText(List<String> lines) {
    final fullText = lines.join('\n');
    if (_searchQuery.isEmpty) {
      return [
        TextSpan(
          text: fullText,
          style: const TextStyle(
            fontFamily: 'Consolas, monospace',
            fontSize: 13,
            height: 1.5,
            color: Color(0xFFD4D4D4),
          ),
        )
      ];
    }

    final spans = <TextSpan>[];
    final lowerText = fullText.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    int start = 0;

    while (start < fullText.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: fullText.substring(start),
          style: const TextStyle(fontFamily: 'Consolas, monospace', fontSize: 13, height: 1.5, color: Color(0xFFD4D4D4)),
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: fullText.substring(start, index),
          style: const TextStyle(fontFamily: 'Consolas, monospace', fontSize: 13, height: 1.5, color: Color(0xFFD4D4D4)),
        ));
      }

      spans.add(TextSpan(
        text: fullText.substring(index, index + lowerQuery.length),
        style: const TextStyle(
          fontFamily: 'Consolas, monospace',
          fontSize: 13,
          height: 1.5,
          backgroundColor: Colors.amber,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + lowerQuery.length;
    }

    return spans;
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
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
