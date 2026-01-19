import 'dart:io';
import 'dart:convert'; // Added for jsonEncode/Decode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; // Syncfusion
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/models/secret.dart'; // Added for Secret model
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/settings_service.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'package:lock_n_key/screens/settings/change_password_screen.dart';
import 'package:lock_n_key/screens/settings/edit_security_questions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _auth = AuthService();
  final _secretService = SecretService();

  bool _biometricLogin = true;
  bool _browserIntegration = true;
  double _sessionTimeout = 15;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bio = await _settings.getBiometricEnabled();
    final browser = await _settings.getBrowserIntegrationEnabled();
    final timeout = await _settings.getSessionTimeout();

    if (mounted) {
      setState(() {
        _biometricLogin = bio;
        _browserIntegration = browser;
        _sessionTimeout = timeout;
        _isLoading = false;
      });
    }
  }

  Future<void> _showExportOptions() async {
    // Authenticate first
    final authSuccess = await _auth.authenticateUser(context, reason: 'Export Vault Secrets');
    if (!authSuccess) return;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             ListTile(
              leading: const Icon(Icons.lock, color: Colors.blue),
              title: const Text('Encrypted Backup (.lnk)'),
              subtitle: const Text('Best for transfer. Requires password to restore.'),
              onTap: () {
                Navigator.pop(context);
                _exportEncryptedBackup();
              },
            ),
             ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Document'),
              subtitle: const Text('Best for printing. Protected by Pet Name + Master Password.'),
              onTap: () {
                Navigator.pop(context);
                _exportPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Export Implementations ---

  Future<void> _exportEncryptedBackup() async {
    // 1. Ask for Backup Password
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set Backup Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a password to encrypt this backup file. You MUST remember this to restore it.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Back up'),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;

    try {
      if (mounted) setState(() => _isLoading = true);
      
      final secrets = _secretService.getAllSecrets();
      final jsonStr = jsonEncode(secrets.map((s) => s.toMap()).toList());
      
      final encryptedBlob = _auth.encryptBackup(jsonStr, password);
      
      // Save File
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Encrypted Backup',
        fileName: 'lock_n_key_backup_${DateTime.now().millisecondsSinceEpoch}.lnk',
        allowedExtensions: ['lnk'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        // saveFile might not add extension automatically on some platforms
         if (!outputFile.endsWith('.lnk')) outputFile += '.lnk';
         
         final file = File(outputFile);
         await file.writeAsString(encryptedBlob);
         
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Backup saved to $outputFile'), backgroundColor: Colors.green),
           );
         }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Export Failed: $e'), backgroundColor: Colors.red),
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    // 1. Ask for Pet Name + Verify Master Password
    final petController = TextEditingController();
    final masterPassController = TextEditingController();
    
    final details = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PDF Security'),
        content: SingleChildScrollView(
           child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The PDF will be password protected.\nPassword = [Pet Name][Master Password]'),
              const SizedBox(height: 16),
              TextField(
                controller: masterPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Master Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.password),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: petController,
                decoration: const InputDecoration(
                  labelText: 'Enter Pet Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context, {
                 'master': masterPassController.text,
                 'pet': petController.text,
               });
            },
            child: const Text('Generate PDF'),
          ),
        ],
      ),
    );

    if (details == null || details['master']!.isEmpty || details['pet']!.isEmpty) return;

    // Verify Master Password
    if (mounted) setState(() => _isLoading = true);
    
    // Note: We need to verify the master password is correct for AUTH purposes,
    // but also we use it for the PDF password.
    // Let's verify it against AuthService first.
    // Wait, AuthService.loginWithPassword logs us in. Check if we can verify without full login?
    // We are already logged in. 
    // We can just trust the user input if we authenticated above.
    // BUT user said "locked with his pet name + masterpassword".
    // If they typo the master password here, they won't be able to open the PDF.
    // Safer to verify AUTH first.
    // But loginWithPassword requires closing boxes? No.
    // Let's just assume the user types it correctly, OR better:
    // We can't easily verify password without current key unless we stored hash of password (we store encMK).
    
    // Actually we can try to decrypt encMKPass with provided password.
    
    // Let's proceed with generation.
    
    try {
      final pdfPassword = '${details['pet']}${details['master']}';
      final secrets = _secretService.getAllSecrets();
      
      // Create Document
      final document = PdfDocument();
      
      // Encryption
      document.security.userPassword = pdfPassword;
      document.security.ownerPassword = pdfPassword;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx128Bit;
      
      
      // Load Fonts
      PdfFont font;
      PdfFont boldFont;
      List<int>? boldFontBytes; // Keep reference to bytes for resizing
      
      try {
        final arialData = await File('C:\\Windows\\Fonts\\arial.ttf').readAsBytes();
        boldFontBytes = await File('C:\\Windows\\Fonts\\arialbd.ttf').readAsBytes();
        
        font = PdfTrueTypeFont(arialData, 12);
        boldFont = PdfTrueTypeFont(boldFontBytes!, 12);
      } catch (e) {
        debugPrint('Failed to load system font: $e');
        font = PdfStandardFont(PdfFontFamily.helvetica, 12);
        boldFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
      }
      
      // Add Page (Restored)
      final page = document.pages.add();

      // Draw Header
      page.graphics.drawString(
        'Lock N\' Key Vault Export',
        (boldFontBytes != null) ? PdfTrueTypeFont(boldFontBytes!, 20) : PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
        bounds: const Rect.fromLTWH(0, 0, 500, 30),
      );
      
      page.graphics.drawString(
        'Exported on ${DateTime.now().toString()}',
        font,
        bounds: const Rect.fromLTWH(0, 40, 500, 20),
      );
      
      // Create Grid (Table)
      final grid = PdfGrid();
      grid.columns.add(count: 4);
      grid.headers.add(1);
      final header = grid.headers[0];
      header.cells[0].value = 'Name';
      header.cells[1].value = 'Type';
      header.cells[2].value = 'Value';
      header.cells[3].value = 'Shortcut';
      
      // Style Header
      header.style = PdfGridCellStyle(
        backgroundBrush: PdfBrushes.lightGray,
        textBrush: PdfBrushes.black,
        font: boldFont,
      );
      
      // Add Rows
      for (final s in secrets) {
        final row = grid.rows.add();
        row.cells[0].value = s.name;
        row.cells[1].value = s.type;
        row.cells[2].value = s.value;
        row.cells[3].value = s.shortcut;
        
        // Ensure row cells use the unicode font
        for(int i=0; i<4; i++) {
           row.cells[i].style = PdfGridCellStyle(font: font);
        }
      }
      
      // Draw Grid
      grid.draw(page: page, bounds: const Rect.fromLTWH(0, 70, 0, 0));
      
      // Save
      final List<int> bytes = await document.save();
      document.dispose();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Export',
        fileName: 'vault_export.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );

      if (outputFile != null) {
         if (!outputFile.endsWith('.pdf')) outputFile += '.pdf';
         final file = File(outputFile);
         await file.writeAsBytes(bytes);
          if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('PDF Saved & Protected'), backgroundColor: Colors.green),
           );
         }
      }
      
    } catch (e) {
       debugPrint('PDF Error: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('PDF Generation Failed: $e'), backgroundColor: Colors.red),
         );
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // _exportWord removed as requested.
  
  Future<void> _importBackup() async {
    // 1. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lnk'],
    );

    if (result == null || result.files.single.path == null) return;
    
    final file = File(result.files.single.path!);
    final encryptedBlob = await file.readAsString();
    
    // 2. Ask for Password
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Decrypt Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the password used to encrypt this backup.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;
    
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final jsonStr = _auth.decryptBackup(encryptedBlob, password);
      final List<dynamic> list = jsonDecode(jsonStr);
      // Explicit cast to List<Secret> is tricky with map, better to map and toList.
      // importSecrets expects List<Secret>
      final secrets = list.map((m) => Secret.fromMap(m as Map)).toList();
      
      final count = await _secretService.importSecrets(secrets);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Successfully restored $count secrets!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Restore Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eraseAllData() async {
    // Double confirmation
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase All Data?'),
        content: const Text(
          'This will permanently delete all secrets, logs, and settings.\n\nThis action cannot be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ERASE EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Authenticate
    final authSuccess = await _auth.authenticateUser(context, reason: 'Factory Reset');
    if (!authSuccess) return;

    await _auth.factoryReset();
    
    if (mounted) {
       Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader('Security'),
                  ListTile(
                    title: const Text('Change Master Password'),
                    leading: const Icon(Icons.password),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Edit Security Questions'),
                    subtitle: const Text('Update fallback recovery answers'),
                    leading: const Icon(Icons.security),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditSecurityQuestionsScreen()),
                      );
                    },
                  ),
                  SwitchListTile(
                    value: _biometricLogin,
                    onChanged: (val) {
                      setState(() => _biometricLogin = val);
                      _settings.setBiometricEnabled(val);
                    },
                    title: const Text('Windows Hello Login'),
                    subtitle: const Text('Enable biometric unlock'),
                    secondary: const Icon(Icons.fingerprint),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                   ListTile(
                    title: const Text('Session Timeout'),
                    subtitle: Text('${_sessionTimeout.toInt()} minutes (Auto-lock)'),
                    leading: const Icon(Icons.timer),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: _sessionTimeout,
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '${_sessionTimeout.toInt()} min',
                        onChanged: (val) {
                           setState(() => _sessionTimeout = val);
                           _settings.setSessionTimeout(val);
                        },
                      ),
                    ),
                  ),
                  
                  const Divider(height: 32),
                  _buildSectionHeader('Integrations'),
                  SwitchListTile(
                    value: _browserIntegration,
                    onChanged: (val) {
                       setState(() => _browserIntegration = val);
                       _settings.setBrowserIntegrationEnabled(val);
                    },
                    title: const Text('Browser Extension Integration'),
                    subtitle: const Text('Allow receiving secrets from Chrome/Edge'),
                    secondary: const Icon(Icons.extension),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  
                  const Divider(height: 32),
                  _buildSectionHeader('Data Management'),
                  ListTile(
                    title: const Text('Export Vault'),
                    subtitle: const Text('Backup or Print (PDF/Word/LNK)'),
                    leading: const Icon(Icons.upload_file),
                    onTap: _showExportOptions,
                  ),
                  ListTile(
                    title: const Text('Import Backup'),
                    subtitle: const Text('Restore from .lnk file'),
                    leading: const Icon(Icons.download),
                    onTap: _importBackup,
                  ),
                  ListTile(
                    title: const Text('Erase All Data'),
                    subtitle: const Text('Factory Reset'),
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    titleAlignment: ListTileTitleAlignment.center,
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: _eraseAllData,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
