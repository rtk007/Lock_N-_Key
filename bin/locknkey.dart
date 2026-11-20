import 'dart:convert';
import 'dart:io';

const String _prefix = 'LNK:';
const String _serverHost = '127.0.0.1';
const int _serverPort = 45454;
const String _serverPath = '/secrets/resolve';

void main(List<String> args) async {
  if (args.isEmpty || args.first != 'run') {
    print('Usage: locknkey run <command> [arguments...]');
    exit(1);
  }

  final commandArgsList = args.sublist(1);
  if (commandArgsList.isEmpty) {
    print('Error: Missing target command.');
    print('Usage: locknkey run <command> [arguments...]');
    exit(1);
  }

  final command = commandArgsList.first;
  final commandArgs = commandArgsList.sublist(1);

  // 1. Identify aliases in environment and local .env files
  final env = Map<String, String>.from(Platform.environment);
  
  // Read local .env files if they exist
  for (final filename in ['.env', '.env.local']) {
    final file = File(filename);
    if (file.existsSync()) {
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex > 0) {
          final key = trimmed.substring(0, eqIndex).trim();
          final val = trimmed.substring(eqIndex + 1).trim();
          env[key] = val; // Add to our working environment
        }
      }
    }
  }

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
          exit(1);
        }
      } else if (response.statusCode == 403) {
        print('Error: Lock N\' Key vault is locked. Please open the app and unlock it.');
        exit(1);
      } else {
        print('Error communicating with Lock N\' Key server: HTTP ${response.statusCode}');
        exit(1);
      }
    } catch (e) {
      print('Error: Could not connect to Lock N\' Key on port $_serverPort. Is the app running?');
      exit(1);
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
    exit(exitCode);
  } catch (e) {
    print('Error launching process: $e');
    exit(1);
  }
}
