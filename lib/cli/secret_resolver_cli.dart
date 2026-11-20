import 'dart:convert';
import 'dart:io';

class SecretResolverCli {
  static const String _prefix = 'LNK:';
  static const String _serverHost = '127.0.0.1';
  static const int _serverPort = 45454;
  static const String _serverPath = '/secrets/resolve';

  static Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      print('Usage: locknkey run <command> [arguments...]');
      return 1;
    }

    final command = args.first;
    final commandArgs = args.sublist(1);

    // 1. Identify aliases in environment
    final env = Platform.environment;
    final aliasesToResolve = <String>{};

    for (final entry in env.entries) {
      if (entry.value.startsWith(_prefix)) {
        aliasesToResolve.add(entry.value.substring(_prefix.length));
      }
    }

    // 2. Resolve aliases if needed
    Map<String, String> resolvedSecrets = {};
    if (aliasesToResolve.isNotEmpty) {
      try {
        final client = HttpClient();
        final request = await client.post(_serverHost, _serverPort, _serverPath);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'aliases': aliasesToResolve.toList()}));

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          if (data['success'] == true) {
            resolvedSecrets = Map<String, String>.from(data['secrets']);
          } else {
            print('Error resolving secrets: ${data['error']}');
            return 1;
          }
        } else if (response.statusCode == 403) {
          print('Error: Lock N\' Key vault is locked or authentication failed.');
          return 1;
        } else {
          print('Error communicating with Lock N\' Key server: HTTP ${response.statusCode}');
          return 1;
        }
      } catch (e) {
        print('Error: Could not connect to Lock N\' Key. Is the app running?');
        return 1;
      }
    }

    // 3. Build new environment
    final childEnv = Map<String, String>.from(env);
    for (final entry in env.entries) {
      if (entry.value.startsWith(_prefix)) {
        final alias = entry.value.substring(_prefix.length);
        if (resolvedSecrets.containsKey(alias)) {
          childEnv[entry.key] = resolvedSecrets[alias]!;
        } else {
          print('Warning: Alias "$alias" not found in Lock N\' Key vault.');
        }
      }
    }

    // 4. Launch child process
    try {
      final process = await Process.start(
        command,
        commandArgs,
        environment: childEnv,
        mode: ProcessStartMode.inheritStdio,
        runInShell: true, // Needed for commands like 'npm' on Windows
      );

      final exitCode = await process.exitCode;
      return exitCode;
    } catch (e) {
      print('Error launching process: $e');
      return 1;
    }
  }
}
