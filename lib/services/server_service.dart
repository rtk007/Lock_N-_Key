import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:lock_n_key/services/secret_service.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:uuid/uuid.dart';

import 'package:window_manager/window_manager.dart';
import 'package:lock_n_key/services/auth_service.dart';
import 'package:lock_n_key/services/settings_service.dart';

class ServerService {
  HttpServer? _server;
  final SecretService _secretService = SecretService();
  final AuthService _auth = AuthService();
  final SettingsService _settings = SettingsService();

  Future<void> start() async {
    final router = Router();

    // CORS Headers Map
    final _corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type',
    };

    // Handler for saving secrets
    router.post('/secrets/add', (Request request) async {
      try {
        // 0. Check Feature Flag
        if (!await _settings.getBrowserIntegrationEnabled()) {
          return Response.forbidden('Browser integration is disabled in settings.', headers: _corsHeaders);
        }

        // 1. Check Auth & Unlock if needed
        if (!_auth.isAuthenticated) {
          debugPrint('Server: Vault locked. Requesting user unlock...');
          
          await windowManager.show();
          await windowManager.focus();
          // Request attention / auth
          _auth.requestAuth();

          // Wait for login (Poll for 60 seconds)
          bool unlocked = false;
          for (int i = 0; i < 60; i++) {
            if (_auth.isAuthenticated) {
              unlocked = true;
              break;
            }
            await Future.delayed(const Duration(seconds: 1));
          }

          if (!unlocked) {
            return Response.forbidden('Vault is locked. Please login via the app.', headers: _corsHeaders);
          }
          
          // Optional: Hide window again if we just unlocked it? 
          // Current behavior: Leave it open as per standard UX, or hide if requested.
          // User asked: "it may close". Let's hide it to be cool.
          await windowManager.hide();
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);

        if (data['name'] == null || data['value'] == null) {
          return Response.badRequest(body: 'Missing name or value', headers: _corsHeaders);
        }

        final secret = Secret(
          id: const Uuid().v4(),
          name: data['name'],
          value: data['value'],
          type: data['type'] ?? 'Password',
          shortcut: data['shortcut'] ?? '',
          tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
          createdAt: DateTime.now(),
        );

        await _secretService.saveSecret(secret);
        return Response.ok(jsonEncode({'success': true, 'id': secret.id}), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: 'Failed to save secret: $e', headers: _corsHeaders);
      }
    });

    // Handle Preflight OPTIONS
    router.options('/secrets/add', (Request request) {
      return Response.ok('', headers: _corsHeaders);
    });

    // Manual CORS Middleware
    Middleware corsMiddleware() {
      return (Handler innerHandler) {
        return (Request request) async {
          final response = await innerHandler(request);
          return response.change(headers: _corsHeaders);
        };
      };
    }

    final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(router);

    // Loopback only for security
    try {
      _server = await io.serve(handler, InternetAddress.loopbackIPv4, 45454);
      debugPrint('Local Server listening on port ${_server!.port}');
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048) {
        debugPrint('Server: Port 45454 is already in use. Assuming another instance is running.');
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Server: Failed to start: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close();
  }
}
