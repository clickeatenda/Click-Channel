import 'package:shared_preferences/shared_preferences.dart';

/// Mock implementation replacing FlutterSecureStorage
/// Uses SharedPreferences implicitly (NOT SECURE - DEV ONLY)
class FlutterSecureStorage {
  const FlutterSecureStorage();

  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      await delete(key: key);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
