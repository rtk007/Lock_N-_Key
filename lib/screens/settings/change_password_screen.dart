import 'package:flutter/material.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/widgets/password_strength_indicator.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _handleChange() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newPasswordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService().changeMasterPassword(_newPasswordController.text);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Master password changed successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to change password'), backgroundColor: Colors.red),
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
        title: const Text('Change Master Password'),
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

                       // Warning Banner
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: Colors.amber.withOpacity(0.1),
                           border: Border.all(color: Colors.amber),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Row(
                           children: [
                             const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Text(
                                 'Changing your Master Password will re-encrypt your entire vault. Do not forget this new password!',
                                 style: TextStyle(color: Colors.amber[900], fontSize: 13),
                               ),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 24),
                       
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        validator: validatePasswordStrength,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'New Master Password',
                          prefixIcon: Icon(Icons.lock_reset),
                          helperText: 'Using a strong passphrase is recommended.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Strength Indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: PasswordStrengthIndicator(password: _newPasswordController.text),
                      ),
                      const SizedBox(height: 24),
                      
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: Icon(Icons.check_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_confirmController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                _newPasswordController.text == _confirmController.text 
                                  ? Icons.check 
                                  : Icons.close,
                                size: 16,
                                color: _newPasswordController.text == _confirmController.text
                                  ? Colors.green
                                  : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _newPasswordController.text == _confirmController.text
                                    ? 'Passwords match'
                                    : 'Passwords do not match',
                                style: TextStyle(
                                  color: _newPasswordController.text == _confirmController.text
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleChange,
                          icon: _isLoading 
                            ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.save),
                          label: const Text('UPDATE MASTER PASSWORD'),
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
