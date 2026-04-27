import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;
import 'prefs.dart';

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
  /// Backend base URL (não utilizado - app opera em modo front-only)
  static String get backendUrl {
    try {
      final direct = dotenv_pkg.dotenv.env['BACKEND_URL'];
      if (direct != null && direct.trim().isNotEmpty) {
        return direct.trim().replaceAll(RegExp(r'/$'), '');
      }
    } catch (_) {}
    return '';
  }

  static bool get useManagedAccess {
    try {
      final v = dotenv_pkg.dotenv.env['USE_CLICK_SAAS_AUTH'];
      if (v != null) {
        final s = v.trim().toLowerCase();
        return s == '1' || s == 'true' || s == 'yes' || s == 'on';
      }
    } catch (_) {}

    return backendUrl.isNotEmpty;
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

  // Runtime override set via settings screen (persisted via Prefs).
  static String? _playlistOverride;

  /// Returns the runtime override if set, otherwise carrega de Prefs (NUNCA usa .env como fallback).
  /// A playlist DEVE ser configurada pelo usuário via Settings.
  /// IMPORTANTE: Sempre verifica Prefs para garantir persistência
  static String? get playlistRuntime {
    // SEMPRE verifica Prefs primeiro (garante persistência após reiniciar app)
    try {
      final saved = Prefs.getPlaylistOverride();
      if (saved != null && saved.isNotEmpty) {
        // Se override em memória é diferente do salvo, atualiza
        if (_playlistOverride != saved) {
          print('🔄 Config.playlistRuntime: Sincronizando override com Prefs...');
          _playlistOverride = saved;
        }
        return saved;
      }
    } catch (e) {
      print('❌ Config.playlistRuntime: Erro ao carregar de Prefs: $e');
    }
    
    // Se não tem em Prefs, usa override em memória (se existir)
    if (_playlistOverride != null && _playlistOverride!.isNotEmpty) {
      return _playlistOverride;
    }
    
    return null;
  }

  /// Set or clear the runtime override for playlist URL.
  static void setPlaylistOverride(String? value) {
    _playlistOverride = (value != null && value.trim().isEmpty) ? null : value?.trim();
  }

  /// Carrega playlist de Prefs (chamado no main.dart)
  static Future<String?> loadPlaylistFromPrefs() async {
    await Prefs.init();
    final saved = Prefs.getPlaylistOverride();
    if (saved != null && saved.isNotEmpty) {
      _playlistOverride = saved;
      return saved;
    }
    return null;
  }

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

  /// TMDB API Key (Hardcoded default)
  static String get tmdbApiKey {
    return 'a274643800798d966ea5556ad951ff8d';
  }
}
