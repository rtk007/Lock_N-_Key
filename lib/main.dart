import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lock_n_key/app.dart';
import 'package:lock_n_key/screens/quick_access_overlay.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lock_n_key/services/server_service.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:lock_n_key/services/auth_service.dart';

import 'package:path_provider/path_provider.dart';


Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use ApplicationSupportDirectory to avoid OneDrive syncing 'Documents' and locking files
  final appDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(appDir.path);
  
  // Initialize Window Manager
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    center: true,
    backgroundColor: null,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  // Check if started with minimized flag
  bool startMinimized = args.contains('--minimized');

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!startMinimized) {
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.hide();
    }
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setPreventClose(true); // REQUIRED for "Hide on Close"
  });

  // Setup Auto Start
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  launchAtStartup.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
    args: ['--minimized'],
  );
  await launchAtStartup.enable();

  // Setup System Tray
  String iconPath = 'assets/images/logo.png';
  if (kReleaseMode) {
    iconPath = 'data/flutter_assets/$iconPath';
  }
  await trayManager.setIcon(iconPath);
  
  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'show_window',
        label: 'Show Lock N\' Key',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: 'Quit',
      ),
    ],
  );
  await trayManager.setContextMenu(menu);
  
  // Setup Tray Listener
  trayManager.addListener(_TrayHandler());

  // Initialize Hotkey Manager
  await hotKeyManager.unregisterAll();
  
  HotKey hotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );
  
  final AuthService _auth = AuthService();

  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (hotKey) async {
       if (await windowManager.isMinimized() || !(await windowManager.isVisible())) {
        await windowManager.show();
        await windowManager.restore();
        await windowManager.focus();
      }
      
      // Check Auth
      if (!_auth.isAuthenticated) {
        await windowManager.show();
        await windowManager.focus();
        _auth.requestAuth(); // Trigger Biometrics
        return; // Stop here, don't open overlay yet
      }

      await windowManager.show();
      await windowManager.focus();
      
      navigatorKey.currentState?.push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => QuickAccessOverlay(
            onClose: () => navigatorKey.currentState?.pop()
          ),
        ),
      );
    },
  );
  
  // Start Local Server
  final serverService = ServerService();
  serverService.start();

  runApp(const LockNKeyApp());
}


class _TrayHandler with TrayListener {
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy(); // Explicitly destroy to close
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
