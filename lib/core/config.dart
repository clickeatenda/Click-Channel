import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;

class Config {
  /// When true, the app operates entirely in front-end mode with no backend calls.
  /// Read from .env (key: FRONT_ONLY). Defaults to true.
  static bool get frontOnly {
    try {
      final v = dotenv_pkg.dotenv.env['FRONT_ONLY'];
      if (v == null) return true;
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'on';
    } catch (_) {
      return true;
    }
  }

  /// When true, app will start directly on Settings for quick testing.
  /// Read from .env (key: AUTO_OPEN_SETTINGS). Defaults to false.
  static bool get autoOpenSettings {
    try {
      final v = dotenv_pkg.dotenv.env['AUTO_OPEN_SETTINGS'];
      if (v == null) return false;
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'on';
    } catch (_) {
      return false;
    }
  }
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

  /// Optional M3U playlist URL (option B: parsing on the app side)
  static String? get playlistUrl {
    try {
      final v = dotenv_pkg.dotenv.env['M3U_PLAYLIST_URL'];
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  // Runtime override set via settings screen (not persisted between app restarts).
  static String? _playlistOverride;

  /// Returns the runtime override if set, otherwise the .env value.
  static String? get playlistRuntime => _playlistOverride ?? playlistUrl;

  /// Set or clear the runtime override for playlist URL.
  static void setPlaylistOverride(String? value) {
    _playlistOverride = (value != null && value.trim().isEmpty) ? null : value?.trim();
  }

  // Persistence handled via Prefs directly in settings screen.

  /// Optional curated featured JSON URL (key: FEATURED_JSON_URL)
  static String? get curatedFeaturedUrl {
    try {
      final v = dotenv_pkg.dotenv.env['FEATURED_JSON_URL'];
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
    }
  }
}
