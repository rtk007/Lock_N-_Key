import 'package:flutter/material.dart';
import 'package:lock_n_key/routes.dart';
import 'package:lock_n_key/theme.dart';
// Screens imports
import 'package:lock_n_key/screens/welcome_screen.dart';
import 'package:lock_n_key/screens/register_screen.dart';
import 'package:lock_n_key/screens/login_screen.dart';
import 'package:lock_n_key/screens/recovery_screen.dart';
import 'package:lock_n_key/screens/dashboard_screen.dart';
import 'package:lock_n_key/screens/secrets_list_screen.dart';
import 'package:lock_n_key/screens/add_edit_secret_screen.dart';
import 'package:lock_n_key/screens/audit_logs_screen.dart';
import 'package:lock_n_key/screens/settings_screen.dart';
import 'package:lock_n_key/screens/about_screen.dart';
import 'package:lock_n_key/screens/tutorial_screen.dart';
import 'package:lock_n_key/main.dart'; // import for navigatorKey

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lock_n_key/services/auth_service.dart';

class LockNKeyApp extends StatefulWidget {
  const LockNKeyApp({super.key});

  @override
  State<LockNKeyApp> createState() => _LockNKeyAppState();
}

class _LockNKeyAppState extends State<LockNKeyApp> with WindowListener, TrayListener {
  
  // Note: We need a subscription to listen to logout triggers
  // But we can't listen in initState directly if we want to use context for navigation 
  // unless we use navigatorKey.
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    
    // Listen for Auto-Logout
    AuthService().logoutTrigger.listen((_) {
      if (mounted) {
         debugPrint('LockNKeyApp: Received logout trigger, navigating to Login...');
         // Schedule navigation to the next frame to avoid locked errors
         WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
         });
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  // --- Window Events ---

  @override
  void onWindowClose() async {
    // Prevent Close -> Hide instead
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      await windowManager.hide();
    }
  }

  // Note: We need to enable preventClose in main.dart first, or do it here.
  // Best to set it once window is ready.

  // --- Tray Events ---

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy(); // Actually quit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AuthService().resetSessionTimer(),
      onPointerMove: (_) => AuthService().resetSessionTimer(),
      onPointerUp: (_) => AuthService().resetSessionTimer(),
      child: CallbackShortcuts(
        bindings: {
          // Binding to capture any key press is tricky with just Shortcuts
          // We can use KeyboardListener instead or Focus widget with onKey
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
             AuthService().resetSessionTimer();
             return KeyEventResult.ignored; // Let others handle it
          },
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Lock N\' Key',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            initialRoute: AppRoutes.welcome,
            routes: {
              AppRoutes.welcome: (context) => const WelcomeScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.recovery: (context) => const RecoveryScreen(),
              AppRoutes.dashboard: (context) => const DashboardScreen(),
              AppRoutes.secretsList: (context) => const SecretsListScreen(),
              AppRoutes.addSecret: (context) => const AddEditSecretScreen(),
              AppRoutes.auditLogs: (context) => const AuditLogsScreen(),
              AppRoutes.settings: (context) => const SettingsScreen(),
              AppRoutes.about: (context) => const AboutScreen(),
              AppRoutes.tutorial: (context) => const TutorialScreen(),
            },
          ),
        ),
      ),
    );
  }
}
