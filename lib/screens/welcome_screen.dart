import 'package:flutter/material.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isRegistered = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final registered = await AuthService().isUserRegistered();
    if (mounted) {
      setState(() {
        _isRegistered = registered;
        _isChecking = false;
      });
    }
  }

  Future<void> _handleGetStarted() async {
    Navigator.pushNamed(context, AppRoutes.register);
  }

  Future<void> _handleLogin() async {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 60),
              
              // App Name
              Text(
                'LOCK N’ KEY',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'The Developer’s Secure Vault',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 80),
              
              // Buttons
              if (!_isChecking)
                if (_isRegistered)
                  SizedBox(
                    width: 250,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _handleLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('UNLOCK VAULT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  SizedBox(
                    width: 250,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _handleGetStarted,
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('GET STARTED', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
