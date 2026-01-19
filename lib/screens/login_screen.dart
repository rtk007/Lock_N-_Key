import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleBiometricUnlock();
    });

    // Listen for external auth requests (e.g. from Extension)
    _authSubscription = _authService.authTrigger.listen((_) {
      if (mounted) {
        _handleBiometricUnlock();
        // Also ensure password field is focused if bio fails/cancels
        FocusScope.of(context).requestFocus(FocusNode()); 
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordUnlock() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final success = await _authService.loginWithPassword(password);
      if (success) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            AppRoutes.dashboard, 
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid password'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricUnlock() async {
    // ... (existing code omitted for brevity in prompt, keeping existing)
    try {
      final success = await _authService.loginWithBiometrics();
      if (success) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            AppRoutes.dashboard, 
            (route) => false,
          );
        }
      } 
    } catch (e) {
       // ...
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Vault'),
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
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 150,
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your Master Password to unlock your secure vault.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Master Password',
                        prefixIcon: Icon(Icons.password),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _handlePasswordUnlock(),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _handlePasswordUnlock,
                        icon: _isLoading 
                         ? Container(width: 20, height: 20, padding: const EdgeInsets.all(2), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                         : const Icon(Icons.lock_open),
                        label: const Text('UNLOCK VAULT'),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    OutlinedButton.icon(
                      onPressed: _handleBiometricUnlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('WINDOWS HELLO'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    TextButton(
                      onPressed: () {
                         Navigator.pushNamed(context, AppRoutes.recovery);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                      child: const Text('Forgot Password? Recover Account'),
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
