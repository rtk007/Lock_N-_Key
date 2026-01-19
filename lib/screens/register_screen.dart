import 'package:flutter/material.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/widgets/password_strength_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  // Security Questions
  final _petController = TextEditingController();
  final _foodController = TextEditingController();
  final _hobbyController = TextEditingController();
  
  String? _designation;
  bool _biometricEnabled = false;
  bool _isLoading = false;

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmController.text) {
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

      await AuthService().register(
        _nameController.text,
        _passwordController.text,
        _biometricEnabled,
        recoveryAnswers: answers,
      );


      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          AppRoutes.tutorial, 
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating vault: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Registration Successful'),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Welcome to Lock N\' Key!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 10),
              Text('Your secure vault is ready. Would you like a quick tour of the features?'),
              SizedBox(height: 15),
              _buildFeatureItem(Icons.security, 'Secure Storage', 'AES-256 encryption.'),
              _buildFeatureItem(Icons.import_export, 'Cross-Device Restore', 'Clipboard-free unique file import.'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Skip'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context, 
                AppRoutes.dashboard, 
                (route) => false,
              );
            },
          ),
          FilledButton(
            child: const Text('Take Tour'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context, 
                AppRoutes.tutorial, 
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Vault'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Create Your Vault',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up your master identity and security credentials.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Section: Identity
                      Text('Identity Information', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Designation',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        value: _designation,
                        items: const [
                          DropdownMenuItem(value: 'Student', child: Text('Student')),
                          DropdownMenuItem(value: 'Developer', child: Text('Developer')),
                        ],
                        onChanged: (val) => setState(() => _designation = val),
                      ),
                      const SizedBox(height: 32),

                      // Section: Security
                      Text('Security Credentials', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator: validatePasswordStrength,
                        onChanged: (_) => setState(() {}), // Refresh UI for strength indicator
                        decoration: const InputDecoration(
                          labelText: 'Master Password',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                          helperText: 'Min 8 chars, Upper, Lower, Digit, Special',
                          helperMaxLines: 1,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PasswordStrengthIndicator(password: _passwordController.text),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.check_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_confirmController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            _passwordController.text == _confirmController.text
                                ? 'Passwords match'
                                : 'Passwords do not match',
                            style: TextStyle(
                              color: _passwordController.text == _confirmController.text
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Section: Recovery
                      Text('Account Recovery', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'These are the ONLY way to recover your account.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[300], fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _petController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required for recovery',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Pet Name?',
                          prefixIcon: Icon(Icons.pets),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _foodController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required for recovery',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Food?',
                          prefixIcon: Icon(Icons.fastfood),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _hobbyController,
                        validator: (v) => v?.isNotEmpty == true ? null : 'Required for recovery',
                        decoration: const InputDecoration(
                          labelText: 'Favorite Hobby?',
                          prefixIcon: Icon(Icons.sports_esports),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          value: _biometricEnabled,
                          onChanged: (val) => setState(() => _biometricEnabled = val ?? false),
                          title: const Text('Enable Windows Hello'),
                          subtitle: const Text('Use fingerprint/face ID to unlock'),
                          secondary: const Icon(Icons.fingerprint),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleRegistration,
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Text('CREATE VAULT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
