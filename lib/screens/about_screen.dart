import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'LOCK N’ KEY',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(
                'The Developer’s Vault',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              _buildInfoRow('Version', '1.0.0 (Beta)'),
              _buildInfoRow('Developer', 'Ratik Krishna'),
              _buildInfoRow('Built With', 'Flutter Desktop'),
              _buildInfoRow('LinkedIn', 'www.linkedin.com/in/ratik-krishna-m-p-17a661290'),
              
              const SizedBox(height: 48),
              const Text(
                '© 2026 Lock N Key Project',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
