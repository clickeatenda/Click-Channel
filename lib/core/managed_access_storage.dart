import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManagedAccessStorage {
  static const _storage = FlutterSecureStorage();

  static const _modeKey = 'managed_access_mode';
  static const _urlKey = 'managed_access_url';
  static const _usernameKey = 'managed_access_username';
  static const _passwordKey = 'managed_access_password';
  static const _providerLabelKey = 'managed_access_provider_label';

  static Future<void> save({
    required String mode,
    required String url,
    String? username,
    String? password,
    String? providerLabel,
  }) async {
    await _storage.write(key: _modeKey, value: mode);
    await _storage.write(key: _urlKey, value: url);
    if (username == null || username.isEmpty) {
      await _storage.delete(key: _usernameKey);
    } else {
      await _storage.write(key: _usernameKey, value: username);
    }
    if (password == null || password.isEmpty) {
      await _storage.delete(key: _passwordKey);
    } else {
      await _storage.write(key: _passwordKey, value: password);
    }
    if (providerLabel == null || providerLabel.isEmpty) {
      await _storage.delete(key: _providerLabelKey);
    } else {
      await _storage.write(key: _providerLabelKey, value: providerLabel);
    }
  }

  static Future<Map<String, String?>> read() async {
    return {
      'mode': await _storage.read(key: _modeKey),
      'url': await _storage.read(key: _urlKey),
      'username': await _storage.read(key: _usernameKey),
      'password': await _storage.read(key: _passwordKey),
      'providerLabel': await _storage.read(key: _providerLabelKey),
    };
  }

  static Future<void> clear() async {
    await _storage.delete(key: _modeKey);
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _providerLabelKey);
  }
}
