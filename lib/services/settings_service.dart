import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyBioEnabled = 'biometric_enabled';
  static const String _keyBrowserEnabled = 'browser_enabled';
  static const String _keySessionTimeout = 'session_timeout';

  Future<bool> getBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBioEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBioEnabled, value);
  }

  Future<bool> getBrowserIntegrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBrowserEnabled) ?? true;
  }

  Future<void> setBrowserIntegrationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBrowserEnabled, value);
  }

  Future<double> getSessionTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySessionTimeout) ?? 15.0;
  }

  Future<void> setSessionTimeout(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySessionTimeout, value);
  }
}
