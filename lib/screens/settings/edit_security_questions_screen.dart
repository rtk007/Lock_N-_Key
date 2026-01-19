import 'package:flutter/material.dart';
import 'package:lock_n_key/services/auth_service.dart';

class EditSecurityQuestionsScreen extends StatefulWidget {
  const EditSecurityQuestionsScreen({super.key});

  @override
  State<EditSecurityQuestionsScreen> createState() => _EditSecurityQuestionsScreenState();
}

class _EditSecurityQuestionsScreenState extends State<EditSecurityQuestionsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _petController = TextEditingController();
  final _foodController = TextEditingController();
  final _hobbyController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final answers = [
        _petController.text.trim(),
        _foodController.text.trim(),
        _hobbyController.text.trim(),
      ];

      final success = await AuthService().updateSecurityQuestions(answers);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Security questions updated successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update questions'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Security Questions'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       Center(
                         child: Image.asset(
                           'assets/images/logo.png',
                           height: 150,
                         ),
                       ),
                       const SizedBox(height: 24),

                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Theme.of(context).primaryColor.withOpacity(0.1),
                               shape: BoxShape.circle,
                             ),
                             child: Icon(Icons.security, color: Theme.of(context).primaryColor, size: 28),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   'Account Recovery',
                                   style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   'These answers are the ONLY way to recover your account if you forget your Master Password.',
                                   style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                       const Divider(height: 32),
                      
                      TextFormField(
                        controller: _petController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Pet Name?',
                          prefixIcon: Icon(Icons.pets),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _foodController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Food?',
                          prefixIcon: Icon(Icons.fastfood),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _hobbyController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Hobby?',
                          prefixIcon: Icon(Icons.sports_esports),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleUpdate,
                          icon: _isLoading 
                            ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.update),
                          label: const Text('UPDATE RECOVERY QUESTIONS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
