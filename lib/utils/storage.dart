import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<void> saveUser(String userJson) async {
    await _storage.write(key: 'user_data', value: userJson);
  }

  static Future<String?> getUser() async {
    return await _storage.read(key: 'user_data');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}