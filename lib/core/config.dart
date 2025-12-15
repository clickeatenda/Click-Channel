import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;

class Config {
  /// Backend base URL. Will read from .env (key: BACKEND_URL).
  /// Falls back to the default value if not set or not initialized.
  static String get backendUrl {
    try {
      return dotenv_pkg.dotenv.env['BACKEND_URL'] ?? 'http://192.168.3.251:4000';
    } catch (_) {
      // Fallback if dotenv not initialized (e.g., in web before load() completes)
      return 'http://192.168.3.251:4000';
    }
  }
}
