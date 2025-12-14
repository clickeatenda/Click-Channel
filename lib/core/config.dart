import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  /// Backend base URL. Will read from .env (key: BACKEND_URL).
  /// Falls back to the previous hardcoded value if not set.
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://192.168.3.251:4000';
}
