import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Store a credential
  Future<void> saveCredential(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // Retrieve a credential
  Future<String?> getCredential(String key) async {
    return await _storage.read(key: key);
  }

  // Delete a credential
  Future<void> deleteCredential(String key) async {
    await _storage.delete(key: key);
  }

  // Delete all credentials
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Store connection credentials
  Future<void> saveConnectionCredentials(String connectionId, Map<String, String> credentials) async {
    final jsonStr = jsonEncode(credentials);
    await _storage.write(key: 'conn_$connectionId', value: jsonStr);
  }

  // Get connection credentials
  Future<Map<String, String>?> getConnectionCredentials(String connectionId) async {
    final jsonStr = await _storage.read(key: 'conn_$connectionId');
    if (jsonStr == null) return null;
    return Map<String, String>.from(jsonDecode(jsonStr));
  }

  // Delete connection credentials
  Future<void> deleteConnectionCredentials(String connectionId) async {
    await _storage.delete(key: 'conn_$connectionId');
  }

  // Check if master password is set
  Future<bool> hasMasterPassword() async {
    final pwd = await _storage.read(key: 'master_password');
    return pwd != null;
  }

  // Set master password
  Future<void> setMasterPassword(String password) async {
    await _storage.write(key: 'master_password', value: password);
  }

  // Verify master password
  Future<bool> verifyMasterPassword(String password) async {
    final stored = await _storage.read(key: 'master_password');
    return stored == password;
  }
}
