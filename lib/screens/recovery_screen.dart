import 'package:flutter/material.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/widgets/password_strength_indicator.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _petController = TextEditingController();
  final _foodController = TextEditingController();
  final _hobbyController = TextEditingController();
  
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;

  Future<void> _handleRecovery() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newPasswordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final answers = [
        _petController.text.trim(),
        _foodController.text.trim(),
        _hobbyController.text.trim(),
      ];

      final success = await AuthService().recoverAccount(answers, _newPasswordController.text);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account recovered successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pushNamedAndRemoveUntil(
            context, 
            AppRoutes.dashboard, 
            (route) => false,
          );
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recovery failed. Incorrect answers.'), backgroundColor: Colors.red),
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

  Future<void> _factoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset?'),
        content: const Text(
          'If you cannot answer the security questions, your data is lost forever.\n\n'
          'This option will DELETE EVERYTHING and allow you to start fresh.\n\n',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().factoryReset();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Account'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Answer Security Questions',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the answers you set during registration to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    
                    TextFormField(
                      controller: _petController,
                      validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                      decoration: const InputDecoration(
                        labelText: 'Favorite Pet Name?',
                        prefixIcon: Icon(Icons.pets),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _foodController,
                      validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                      decoration: const InputDecoration(
                        labelText: 'Favorite Food?',
                        prefixIcon: Icon(Icons.fastfood),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _hobbyController,
                      validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                      decoration: const InputDecoration(
                        labelText: 'Favorite Hobby?',
                        prefixIcon: Icon(Icons.sports_esports),
                      ),
                    ),

                    const Divider(height: 48),

                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      validator: validatePasswordStrength,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'New Master Password',
                        prefixIcon: Icon(Icons.lock_reset),
                        helperText: 'Min 8 chars, Upper, Lower, Digit, Special',
                      ),
                    ),
                    PasswordStrengthIndicator(password: _newPasswordController.text),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                    ),
                    if (_confirmController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          _newPasswordController.text == _confirmController.text
                              ? 'Passwords match'
                              : 'Passwords do not match',
                          style: TextStyle(
                            color: _newPasswordController.text == _confirmController.text
                                ? Colors.green
                                : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRecovery,
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Text('RECOVER & LOGIN'),
                    ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _factoryReset,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('I forgot these too (Factory Reset)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
