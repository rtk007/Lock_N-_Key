import 'dart:convert';
import 'dart:io';

const String _prefix = 'LNK:';
const String _serverHost = '127.0.0.1';
const int _serverPort = 45454;

void main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h' || args.first == 'help') {
    _printHelp();
    exit(0);
  }

  final command = args.first.toLowerCase();
  final subArgs = args.sublist(1);

  switch (command) {
    case 'run':
      await _handleRun(subArgs);
      break;

    case 'list':
    case 'ls':
      await _handleList(subArgs);
      break;

    case 'get':
      await _handleGet(subArgs);
      break;

    case 'set':
    case 'add':
      await _handleSet(subArgs);
      break;

    case 'delete':
    case 'rm':
      await _handleDelete(subArgs);
      break;

    case 'status':
      await _handleStatus();
      break;

    case 'hook':
      await _handleHook(subArgs);
      break;

    case 'scan':
      await _handleScan(subArgs);
      break;

    default:
      print('Unknown command: "$command"');
      print('Run "locknkey help" to view all available commands.');
      exit(1);
  }
}

void _printHelp() {
  print('''
╔═════════════════════════════════════════════════════════════════════╗
║                      Lock N' Key CLI v1.1.0                         ║
║               The Developer's Zero-Trust Local Vault                ║
╚═════════════════════════════════════════════════════════════════════╝

USAGE:
  locknkey <command> [options]

COMMANDS:
  run <command> [args...]    Inject LNK: aliases and execute child process
  list                       List all stored secrets and shortcuts in vault
  get <alias> [-c, --copy]   Retrieve and print secret value (or copy to clipboard)
  set <alias> [value]        Add or update a secret directly from terminal
  delete <alias>             Remove a secret from vault
  status                     Check vault status and local daemon connectivity
  hook [install|uninstall]   Manage Git pre-commit leak prevention guard
  scan [--staged]            Scan Git staged changes for hardcoded vault secrets
  help                       Show this help information

EXAMPLES:
  locknkey run npm start
  locknkey run docker compose up
  locknkey list
  locknkey get openai_key
  locknkey get stripe_test --copy
  locknkey set prod_db_url "postgresql://admin:pass@db:5432/main"
  locknkey hook install
  locknkey scan --staged
''');
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. locknkey run <cmd> [args...]
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleRun(List<String> args) async {
  if (args.isEmpty) {
    print('Error: Missing target command.');
    print('Usage: locknkey run <command> [arguments...]');
    exit(1);
  }

  final targetCommand = args.first;
  final targetArgs = args.sublist(1);

  // 1. Identify aliases in environment and local .env files
  final env = Map<String, String>.from(Platform.environment);

  for (final filename in ['.env', '.env.local', '.env.development']) {
    final file = File(filename);
    if (file.existsSync()) {
      final lines = file.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex > 0) {
          final key = trimmed.substring(0, eqIndex).trim();
          var val = trimmed.substring(eqIndex + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.substring(1, val.length - 1);
          }
          env[key] = val;
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

  Map<String, String> resolvedSecrets = {};
  if (aliasesToResolve.isNotEmpty) {
    final res = await _postJson('/secrets/resolve', {'aliases': aliasesToResolve.toList()});
    if (res['success'] == true) {
      resolvedSecrets = Map<String, String>.from(res['secrets'] ?? {});
    } else {
      print('Error resolving secrets: ${res['error']}');
      exit(1);
    }
  }

  // Inject resolved secrets
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

  // Execute child process
  try {
    final process = await Process.start(
      targetCommand,
      targetArgs,
      environment: childEnv,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true,
    );

    final exitCode = await process.exitCode;
    exit(exitCode);
  } catch (e) {
    print('Error launching process: $e');
    exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. locknkey list
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleList(List<String> args) async {
  final res = await _getJson('/secrets/list');
  if (res['success'] != true) {
    print('Failed to retrieve secrets: ${res['error'] ?? 'Unknown error'}');
    exit(1);
  }

  final secrets = (res['secrets'] as List<dynamic>?) ?? [];
  if (secrets.isEmpty) {
    print('Your Lock N\' Key vault is empty.');
    print('Add a secret using the desktop app or `locknkey set <alias> <value>`.');
    return;
  }

  print('\nLock N\' Key Vault (${secrets.length} items):');
  print('─' * 80);
  print(
    '${_padRight('NAME', 26)} '
    '${_padRight('SHORTCUT', 16)} '
    '${_padRight('TYPE', 14)} '
    '${_padRight('STATUS', 12)} '
    'EXPIRY',
  );
  print('─' * 80);

  for (final s in secrets) {
    final name = s['name']?.toString() ?? 'Unnamed';
    final shortcut = s['shortcut']?.toString().replaceFirst('//', '') ?? '';
    final type = s['type']?.toString() ?? 'Secret';
    final isExpired = s['isExpired'] == true;
    final isExpiringSoon = s['isExpiringSoon'] == true;

    String statusStr = 'Healthy';
    if (isExpired) {
      statusStr = '[EXPIRED]';
    } else if (isExpiringSoon) {
      statusStr = '[EXPIRING]';
    }

    String expiryStr = 'Never';
    if (s['expiryDate'] != null) {
      final dt = DateTime.tryParse(s['expiryDate'].toString());
      if (dt != null) {
        expiryStr = '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)}';
      }
    }

    print(
      '${_padRight(name, 26)} '
      '${_padRight(shortcut.isNotEmpty ? shortcut : "-", 16)} '
      '${_padRight(type, 14)} '
      '${_padRight(statusStr, 12)} '
      '$expiryStr',
    );
  }
  print('─' * 80);
  print('Tip: Use `locknkey get <shortcut>` to retrieve values in scripts or terminal.\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. locknkey get <alias> [--copy / -c]
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleGet(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: locknkey get <alias> [-c, --copy]');
    exit(1);
  }

  final copyToClipboard = args.contains('-c') || args.contains('--copy');
  final alias = args.firstWhere((a) => !a.startsWith('-'), orElse: () => '');

  if (alias.isEmpty) {
    print('Error: Missing secret alias.');
    exit(1);
  }

  final res = await _postJson('/secrets/get', {'alias': alias});
  if (res['success'] != true) {
    print('Error: ${res['error'] ?? 'Secret not found.'}');
    exit(1);
  }

  final secret = res['secret'] as Map<String, dynamic>;
  final value = secret['value']?.toString() ?? '';

  if (copyToClipboard) {
    await _copyToClipboard(value);
    print('✔ Secret "${secret['name']}" copied to clipboard!');
  } else {
    // Print raw value to stdout (clean for pipes: `$(locknkey get key)`)
    stdout.write(value);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. locknkey set <alias> [value]
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleSet(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: locknkey set <alias> [value] [--name <name>] [--type <type>]');
    exit(1);
  }

  final alias = args.first;
  var value = args.length > 1 && !args[1].startsWith('-') ? args[1] : '';

  String name = alias;
  String type = 'API Key';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--name' && i + 1 < args.length) {
      name = args[i + 1];
    } else if (args[i] == '--type' && i + 1 < args.length) {
      type = args[i + 1];
    }
  }

  if (value.isEmpty) {
    stdout.write('Enter secret value for "$alias": ');
    stdin.echoMode = false;
    value = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    print('');
  }

  if (value.trim().isEmpty) {
    print('Error: Secret value cannot be empty.');
    exit(1);
  }

  final res = await _postJson('/secrets/set', {
    'name': name,
    'shortcut': alias,
    'value': value,
    'type': type,
  });

  if (res['success'] == true) {
    print('✔ Secret "$name" saved to Lock N\' Key vault under alias "$alias".');
  } else {
    print('Failed to save secret: ${res['error']}');
    exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. locknkey delete <alias>
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleDelete(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: locknkey delete <alias>');
    exit(1);
  }

  final alias = args.first;
  stdout.write('Are you sure you want to delete "$alias"? [y/N]: ');
  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  if (confirm != 'y' && confirm != 'yes') {
    print('Aborted.');
    return;
  }

  final res = await _postJson('/secrets/delete', {'alias': alias});
  if (res['success'] == true) {
    print('✔ Secret "$alias" deleted from vault.');
  } else {
    print('Failed to delete: ${res['error']}');
    exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. locknkey status
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleStatus() async {
  final res = await _getJson('/secrets/status');
  if (res['running'] == true) {
    final isAuth = res['authenticated'] == true;
    final count = res['totalSecrets'] ?? 0;
    print('Lock N\' Key Daemon: RUNNING on port $_serverPort');
    print('Vault Status:         ${isAuth ? "UNLOCKED ($count secrets loaded)" : "LOCKED (Authentication required)"}');
  } else {
    print('Lock N\' Key Daemon: NOT RUNNING');
    print('Please launch the Lock N\' Key desktop application.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. locknkey hook [install|uninstall|status]
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleHook(List<String> args) async {
  final action = args.isNotEmpty ? args.first.toLowerCase() : 'install';

  final gitDir = Directory('.git');
  if (!gitDir.existsSync()) {
    print('Error: Current directory is not a Git repository (no .git folder found).');
    print('Navigate to your Git repository root and run `locknkey hook install`.');
    exit(1);
  }

  final hooksDir = Directory('.git/hooks');
  if (!hooksDir.existsSync()) {
    hooksDir.createSync(recursive: true);
  }

  final preCommitFile = File('.git/hooks/pre-commit');

  if (action == 'uninstall' || action == 'remove') {
    if (preCommitFile.existsSync()) {
      preCommitFile.deleteSync();
      print('✔ Lock N\' Key Git pre-commit hook uninstalled.');
    } else {
      print('No pre-commit hook found in .git/hooks/pre-commit.');
    }
    return;
  }

  // Pre-commit script content (works on bash, sh, Git Bash for Windows)
  const hookScript = '''#!/bin/sh
# Lock N' Key Pre-Commit Leak Guard
# Automatically blocks commits containing your stored vault secrets.

if command -v locknkey >/dev/null 2>&1; then
  locknkey scan --staged
  EXIT_CODE=\$?
  if [ \$EXIT_CODE -ne 0 ]; then
    echo ""
    echo "[Lock N' Key Guard] Commit rejected to protect your secrets."
    echo "[Lock N' Key Guard] To bypass this check temporarily, run: git commit --no-verify"
    exit 1
  fi
fi
exit 0
''';

  preCommitFile.writeAsStringSync(hookScript);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', preCommitFile.path]);
  }

  print('✔ Lock N\' Key Git Leak Guard installed successfully in .git/hooks/pre-commit!');
  print('Every `git commit` will now automatically be audited against your vault secrets.');
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. locknkey scan [--staged]
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _handleScan(List<String> args) async {
  final isStagedOnly = args.contains('--staged') || args.isEmpty;

  ProcessResult gitDiff;
  try {
    if (isStagedOnly) {
      gitDiff = Process.runSync('git', ['diff', '--cached', '-U0'], runInShell: true);
    } else {
      gitDiff = Process.runSync('git', ['diff', '-U0'], runInShell: true);
    }
  } catch (e) {
    print('Error running git diff: $e');
    exit(1);
  }

  final diffContent = gitDiff.stdout.toString();
  if (diffContent.trim().isEmpty) {
    // No staged changes
    return;
  }

  final res = await _postJson('/secrets/audit/check-leak', {'content': diffContent});
  if (res['leaked'] == true) {
    final matches = (res['matches'] as List<dynamic>?) ?? [];
    print('\n╔═════════════════════════════════════════════════════════════════════╗');
    print('║       [Lock N\' Key Guard] 🚨 CRITICAL: LEAK DETECTED!              ║');
    print('╚═════════════════════════════════════════════════════════════════════╝');
    print('Your staged changes contain secrets currently stored in your vault:\n');

    for (final m in matches) {
      final name = m['name'];
      final shortcut = m['shortcut']?.toString().replaceFirst('//', '');
      print('  ❌ Secret: "$name" (Shortcut: "$shortcut")');
    }

    print('\n💡 How to fix:');
    print('  1. Remove the plaintext secret from your code.');
    print('  2. Put `LNK:<shortcut>` into your .env file instead.');
    print('  3. Run your program using `locknkey run <command>`.');
    exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities & HTTP Helpers
// ─────────────────────────────────────────────────────────────────────────────
Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
  try {
    final client = HttpClient();
    final request = await client.post(_serverHost, _serverPort, path);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final resBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 403) {
      return {'success': false, 'error': 'Vault is locked. Please unlock Lock N\' Key.'};
    }

    if (resBody.isEmpty) return {'success': response.statusCode == 200};
    return jsonDecode(resBody) as Map<String, dynamic>;
  } catch (e) {
    return {'success': false, 'error': 'Could not connect to Lock N\' Key on port $_serverPort. Is the app running?'};
  }
}

Future<Map<String, dynamic>> _getJson(String path) async {
  try {
    final client = HttpClient();
    final request = await client.get(_serverHost, _serverPort, path);
    final response = await request.close();
    final resBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 403) {
      return {'success': false, 'error': 'Vault is locked. Please unlock Lock N\' Key.'};
    }

    if (resBody.isEmpty) return {'success': response.statusCode == 200};
    return jsonDecode(resBody) as Map<String, dynamic>;
  } catch (e) {
    return {'success': false, 'error': 'Could not connect to Lock N\' Key on port $_serverPort. Is the app running?'};
  }
}

Future<void> _copyToClipboard(String text) async {
  if (Platform.isWindows) {
    final p = await Process.start('powershell', ['-Command', 'Set-Clipboard -Value \$input'], runInShell: true);
    p.stdin.write(text);
    await p.stdin.close();
    await p.exitCode;
  } else if (Platform.isMacOS) {
    final p = await Process.start('pbcopy', []);
    p.stdin.write(text);
    await p.stdin.close();
    await p.exitCode;
  } else if (Platform.isLinux) {
    try {
      final p = await Process.start('xclip', ['-selection', 'clipboard']);
      p.stdin.write(text);
      await p.stdin.close();
      await p.exitCode;
    } catch (_) {}
  }
}

String _padRight(String str, int len) {
  if (str.length >= len) {
    return str.substring(0, len - 2) + '..';
  }
  return str.padRight(len);
}

String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
