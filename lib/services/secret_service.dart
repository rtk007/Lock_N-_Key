import 'package:hive_flutter/hive_flutter.dart';
import 'package:lock_n_key/models/secret.dart';
import 'package:lock_n_key/services/auth_service.dart';

class SecretService {
  final AuthService _auth = AuthService();

  Box get _box => _auth.vaultBox;

  List<Secret> getAllSecrets() {
    final secrets = <Secret>[];
    for (var key in _box.keys) {
      if (key == 'verification') continue; // Skip system keys
      
      final data = _box.get(key);
      if (data is Map) {
        try {
          secrets.add(Secret.fromMap(data));
        } catch (e) {
          // Skipping malformed data
        }
      }
    }
    // Sort by newest first
    secrets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return secrets;
  }

  Future<void> saveSecret(Secret secret) async {
    await _box.put(secret.id, secret.toMap());
  }

  Future<void> deleteSecret(String id) async {
    await _box.delete(id);
  }

  Future<void> incrementUsage(String id) async {
    final data = _box.get(id);
    if (data != null && data is Map) {
      final secret = Secret.fromMap(data);
      final updated = secret.copyWith(usageCount: secret.usageCount + 1);
      await saveSecret(updated);
    }
  }

  Secret? getMostUsedSecret() {
    final secrets = getAllSecrets();
    if (secrets.isEmpty) return null;
    secrets.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    if (secrets.first.usageCount == 0) return null; // No usage yet
    return secrets.first;
  }
  Future<int> importSecrets(List<Secret> newSecrets) async {
    int count = 0;
    for (final secret in newSecrets) {
      // Check if ID exists? Or Name?
      // Strategy: ID collision -> Skip (it's the same secret), Name collision -> Rename or Skip?
      // Let's simply overwrite if ID matches, else add. 
      // User said "secrets are restored".
      // If we are restoring, we probably want to update existing ones.
      
      // Let's regenerate ID to avoid conflicts if it's a "copy" from another user?
      // User said "change my laptop... import secrets".
      // So IDs should be preserved for sync? Or treated as new?
      // Safest: Check ID. If exists, update. If not, add.
      
      await saveSecret(secret);
      count++;
    }
    return count;
  }
}
