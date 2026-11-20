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

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  Future<bool> _ensureUnlocked() async {
    if (_auth.isAuthenticated) return true;

    debugPrint('Server: Vault locked. Requesting user unlock...');
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}

    _auth.requestAuth();

    // Poll for up to 60 seconds
    for (int i = 0; i < 60; i++) {
      if (_auth.isAuthenticated) {
        try {
          await windowManager.hide();
        } catch (_) {}
        return true;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> start() async {
    final router = Router();

    // Health / Ping
    router.get('/ping', (Request request) {
      return Response.ok(jsonEncode({'status': 'ok', 'app': 'Lock N\' Key'}), headers: _corsHeaders);
    });

    // Vault Status (CLI / Extension)
    router.get('/secrets/status', (Request request) {
      return Response.ok(
        jsonEncode({
          'running': true,
          'authenticated': _auth.isAuthenticated,
          'totalSecrets': _auth.isAuthenticated ? _secretService.getAllSecrets().length : 0,
        }),
        headers: _corsHeaders,
      );
    });

    // List all secrets (Metadata only, values masked for safety)
    Future<Response> handleListSecrets(Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden(jsonEncode({'error': 'Vault is locked.'}), headers: _corsHeaders);
        }

        final secrets = _secretService.getAllSecrets();
        final list = secrets.map((s) => {
          'id': s.id,
          'name': s.name,
          'shortcut': s.shortcut,
          'type': s.type,
          'tags': s.tags,
          'fileName': s.fileName,
          'fileSize': s.fileSize,
          'fileExtension': s.fileExtension,
          'isExpired': s.isExpired,
          'isExpiringSoon': s.isExpiringSoon,
          'daysUntilExpiry': s.daysUntilExpiry,
          'expiryDate': s.expiryDate?.toIso8601String(),
          'createdAt': s.createdAt.toIso8601String(),
          'usageCount': s.usageCount,
        }).toList();

        return Response.ok(jsonEncode({'success': true, 'secrets': list}), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: jsonEncode({'error': '$e'}), headers: _corsHeaders);
      }
    }

    router.get('/secrets/list', handleListSecrets);
    router.post('/secrets/list', handleListSecrets);

    // Get a specific secret by alias/name/shortcut
    router.post('/secrets/get', (Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden(jsonEncode({'error': 'Vault is locked.'}), headers: _corsHeaders);
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final alias = (data['alias'] ?? '').toString().trim();

        if (alias.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing alias'}), headers: _corsHeaders);
        }

        final allSecrets = _secretService.getAllSecrets();
        final normalizedAlias = alias.startsWith('//') ? alias : '//$alias';
        
        final matches = allSecrets.where((s) => 
          s.shortcut.toLowerCase() == alias.toLowerCase() ||
          s.shortcut.toLowerCase() == normalizedAlias.toLowerCase() ||
          s.name.toLowerCase() == alias.toLowerCase() ||
          s.id == alias
        );

        if (matches.isEmpty) {
          return Response.notFound(jsonEncode({'error': 'Secret "$alias" not found.'}), headers: _corsHeaders);
        }

        final secret = matches.first;
        await _secretService.incrementUsage(secret.id);

        return Response.ok(jsonEncode({
          'success': true,
          'secret': secret.toMap(),
        }), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: jsonEncode({'error': '$e'}), headers: _corsHeaders);
      }
    });

    // Set / Add / Update secret from CLI
    router.post('/secrets/set', (Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden(jsonEncode({'error': 'Vault is locked.'}), headers: _corsHeaders);
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);

        final name = (data['name'] ?? '').toString().trim();
        final value = (data['value'] ?? '').toString();
        final shortcut = (data['shortcut'] ?? '').toString().trim();
        final type = (data['type'] ?? 'API Key').toString();

        if (name.isEmpty || value.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Name and value are required.'}), headers: _corsHeaders);
        }

        final normalizedShortcut = shortcut.isNotEmpty 
            ? (shortcut.startsWith('//') ? shortcut : '//$shortcut') 
            : '';

        // Check if updating existing
        final allSecrets = _secretService.getAllSecrets();
        Secret? existing;
        if (shortcut.isNotEmpty) {
          final matches = allSecrets.where((s) => s.shortcut == normalizedShortcut);
          if (matches.isNotEmpty) existing = matches.first;
        }
        if (existing == null) {
          final matches = allSecrets.where((s) => s.name.toLowerCase() == name.toLowerCase());
          if (matches.isNotEmpty) existing = matches.first;
        }

        DateTime? expiry;
        if (data['expiryDate'] != null) {
          expiry = DateTime.tryParse(data['expiryDate'].toString());
        }

        final secret = Secret(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          value: value,
          type: type,
          shortcut: normalizedShortcut.isNotEmpty ? normalizedShortcut : (existing?.shortcut ?? ''),
          tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? (existing?.tags ?? []),
          expiryDate: expiry ?? existing?.expiryDate,
          createdAt: existing?.createdAt ?? DateTime.now(),
          notes: data['notes'] ?? existing?.notes,
        );

        await _secretService.saveSecret(secret);
        return Response.ok(jsonEncode({'success': true, 'id': secret.id, 'action': existing != null ? 'updated' : 'created'}), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: jsonEncode({'error': '$e'}), headers: _corsHeaders);
      }
    });

    // Delete secret from CLI
    router.post('/secrets/delete', (Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden(jsonEncode({'error': 'Vault is locked.'}), headers: _corsHeaders);
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final alias = (data['alias'] ?? '').toString().trim();

        if (alias.isEmpty) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing alias to delete.'}), headers: _corsHeaders);
        }

        final allSecrets = _secretService.getAllSecrets();
        final normalizedAlias = alias.startsWith('//') ? alias : '//$alias';
        final matches = allSecrets.where((s) => 
          s.shortcut.toLowerCase() == alias.toLowerCase() ||
          s.shortcut.toLowerCase() == normalizedAlias.toLowerCase() ||
          s.name.toLowerCase() == alias.toLowerCase() ||
          s.id == alias
        );

        if (matches.isEmpty) {
          return Response.notFound(jsonEncode({'error': 'Secret not found.'}), headers: _corsHeaders);
        }

        final secret = matches.first;
        await _secretService.deleteSecret(secret.id);
        return Response.ok(jsonEncode({'success': true, 'deleted': secret.name}), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: jsonEncode({'error': '$e'}), headers: _corsHeaders);
      }
    });

    // Git Leak Guard Scanner Endpoint
    router.post('/secrets/audit/check-leak', (Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden(jsonEncode({'error': 'Vault is locked.'}), headers: _corsHeaders);
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final content = (data['content'] ?? '').toString();

        if (content.isEmpty) {
          return Response.ok(jsonEncode({'leaked': false, 'matches': []}), headers: _corsHeaders);
        }

        final allSecrets = _secretService.getAllSecrets();
        final matches = <Map<String, dynamic>>[];

        for (final secret in allSecrets) {
          final val = secret.value.trim();
          // Avoid matching trivial short strings (e.g. "true", "123", "test") to prevent false positives
          if (val.length < 6) continue;

          if (content.contains(val)) {
            matches.add({
              'name': secret.name,
              'shortcut': secret.shortcut,
              'type': secret.type,
            });
          }
        }

        return Response.ok(jsonEncode({
          'leaked': matches.isNotEmpty,
          'matches': matches,
        }), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: jsonEncode({'error': '$e'}), headers: _corsHeaders);
      }
    });

    // Handler for saving secrets (Browser Extension)
    router.post('/secrets/add', (Request request) async {
      try {
        if (!await _settings.getBrowserIntegrationEnabled()) {
          return Response.forbidden('Browser integration is disabled in settings.', headers: _corsHeaders);
        }

        if (!await _ensureUnlocked()) {
          return Response.forbidden('Vault is locked. Please login via the app.', headers: _corsHeaders);
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

    // Handler for resolving secrets (CLI: locknkey run)
    router.post('/secrets/resolve', (Request request) async {
      try {
        if (!await _ensureUnlocked()) {
          return Response.forbidden('Vault is locked.', headers: _corsHeaders);
        }

        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final aliases = (data['aliases'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        final allSecrets = _secretService.getAllSecrets();
        final resolved = <String, String>{};

        for (final alias in aliases) {
          final normalized = alias.startsWith('//') ? alias : '//$alias';
          final matches = allSecrets.where((s) => 
            s.shortcut == alias || 
            s.shortcut == normalized || 
            s.name == alias
          );
          if (matches.isNotEmpty) {
            resolved[alias] = matches.first.value;
          }
        }

        return Response.ok(jsonEncode({'success': true, 'secrets': resolved}), headers: _corsHeaders);
      } catch (e) {
        debugPrint('Server Error: $e');
        return Response.internalServerError(body: 'Failed to resolve secrets: $e', headers: _corsHeaders);
      }
    });

    // OPTIONS preflight handlers for CORS
    for (final path in [
      '/secrets/status',
      '/secrets/list',
      '/secrets/get',
      '/secrets/set',
      '/secrets/delete',
      '/secrets/audit/check-leak',
      '/secrets/add',
      '/secrets/resolve',
    ]) {
      router.options(path, (Request request) => Response.ok('', headers: _corsHeaders));
    }

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
      .addHandler(router.call);

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
