import 'dart:math';
import 'package:flutter/material.dart';
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
  
  String _type = 'Password';
  final List<String> _types = ['Password', 'API Key', 'Token', 'Note', 'Other'];
  
  bool _isInit = true;
  bool _isEdit = false;
  String? _existingId;
  DateTime _createdAt = DateTime.now();
  DateTime? _expiryDate;

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
        _shortcutController.text = secret.shortcut;
        _tagsController.text = secret.tags.join(', ');
        _expiryDate = secret.expiryDate;
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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final value = _valueController.text; // Value might be preserved/unedited
    final shortcut = _shortcutController.text.trim();
    final tags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final secret = Secret(
      id: _existingId ?? '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      name: name,
      type: _type,
      value: value,
      shortcut: shortcut.startsWith('//') ? shortcut : (shortcut.isNotEmpty ? '//$shortcut' : ''),
      tags: tags,
      expiryDate: _expiryDate,
      createdAt: _createdAt, // Preserve original creation time
    );

    await SecretService().saveSecret(secret);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Secret updated' : 'Secret created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Header Info Card
                   Card(
                     elevation: 2,
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             'Core Information',
                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
                               fontWeight: FontWeight.bold,
                               color: Theme.of(context).colorScheme.primary,
                             ),
                           ),
                           const Divider(),
                           const SizedBox(height: 16),
                           
                           // Name
                           TextFormField(
                            controller: _nameController,
                            validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                            decoration: const InputDecoration(
                              labelText: 'Secret Name',
                              hintText: 'e.g. GitHub Personal Access Token',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Type
                          DropdownButtonFormField<String>(
                            value: _type,
                            items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _type = val);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Secret Type',
                              prefixIcon: Icon(Icons.category_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Value
                           TextFormField(
                            controller: _valueController,
                            obscureText: true,
                            readOnly: _isEdit,
                            validator: (v) => v == null || v.isEmpty ? 'Value is required' : null,
                            maxLines: 1,
                            style: _isEdit ? const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic) : null,
                            decoration: InputDecoration(
                              labelText: _isEdit ? 'Secret Value (Locked)' : 'Secret Value',
                              helperText: _isEdit ? 'For security, re-create the secret to change its value.' : 'This will be securely encrypted.',
                              helperMaxLines: 2,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: const Icon(Icons.visibility_off_outlined), // Hint that it's hidden
                              filled: _isEdit,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                         ],
                       ),
                     ),
                   ),

                   const SizedBox(height: 24),

                   // Metadata Card
                   Card(
                     elevation: 2,
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             'Quick Access & Organization',
                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
                               fontWeight: FontWeight.bold,
                               color: Theme.of(context).colorScheme.primary,
                             ),
                           ),
                           const Divider(),
                           const SizedBox(height: 16),
                           
                           // Shortcut
                           TextFormField(
                            controller: _shortcutController,
                            decoration: const InputDecoration(
                              labelText: 'Global Shortcut (Optional)',
                              hintText: '//github-token',
                              helperText: 'Type this anywhere to paste via Quick Access.',
                              prefixIcon: Icon(Icons.keyboard_command_key),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Tags
                          TextFormField(
                            controller: _tagsController,
                            decoration: const InputDecoration(
                              labelText: 'Tags (Optional)',
                              hintText: 'work, dev, personal',
                              helperText: 'Comma separated values for filtering.',
                              prefixIcon: Icon(Icons.label_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expiry Date
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (date != null) setState(() => _expiryDate = date);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(4), // Match OutlineInputBorder radius
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Expiry Date (Optional)',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                        ),
                                        Text(
                                          _expiryDate == null 
                                            ? 'No Expiry Set' 
                                            : _expiryDate!.toLocal().toString().split(' ')[0],
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_expiryDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _expiryDate = null),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
}
