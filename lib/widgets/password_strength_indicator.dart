import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  // Strength: 0=Very Weak, 1=Weak, 2=Moderate, 3=Strong
  int get  _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    
    // Normalize to 0-4 range roughly
    if (password.length < 8) return 0; // Length is mandatory baseline
    
    // Remap remaining 4 criteria to levels
    // Criteria met: score (1 for length + others)
    // 5 total criteria.
    
    int criteriaMet = 0;
    if (password.length >= 8) criteriaMet++;
    if (password.contains(RegExp(r'[A-Z]'))) criteriaMet++;
    if (password.contains(RegExp(r'[a-z]'))) criteriaMet++;
    if (password.contains(RegExp(r'[0-9]'))) criteriaMet++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) criteriaMet++;
    
    if (password.length < 8) return 0;
    if (criteriaMet <= 2) return 1; // Weak
    if (criteriaMet <= 4) return 2; // Moderate
    return 3; // Strong (All 5)
  }

  String get _label {
    switch (_strength) {
      case 0: return 'Very Weak (Min 8 chars)';
      case 1: return 'Weak';
      case 2: return 'Moderate';
      case 3: return 'Strong';
      default: return '';
    }
  }

  Color get _color {
    switch (_strength) {
      case 0: return Colors.red;
      case 1: return Colors.orange;
      case 2: return Colors.yellow;
      case 3: return Colors.green;
      default: return Colors.grey;
    }
  }
  
  double get _value {
      switch (_strength) {
      case 0: return 0.25;
      case 1: return 0.5;
      case 2: return 0.75;
      case 3: return 1.0;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _value,
          backgroundColor: Colors.grey[800],
          color: _color,
          minHeight: 5,
        ),
        const SizedBox(height: 4),
        Text(
          _label,
          style: TextStyle(color: _color, fontSize: 12),
        ),
      ],
    );
  }
}

// Utility for validation used in Fields
String? validatePasswordStrength(String? value) {
  if (value == null || value.isEmpty) return 'Required';
  if (value.length < 8) return 'Min 8 chars required';
  if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain uppercase';
  if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain lowercase';
  if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain digit';
  if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return 'Must contain special char';
  return null;
}
