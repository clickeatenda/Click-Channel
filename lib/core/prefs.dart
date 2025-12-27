import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _prefs;

  static const String keyPlaylistOverride = 'playlist_url_override';
  static const String keyPlaylistReady = 'playlist_ready';
  static const String keyPlaylistLastDownload = 'playlist_last_download';
  // TMDB API key stored at runtime (set via Settings) - optional
  static const String keyTmdbApiKey = 'tmdb_api_key';

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Sanitize playlist override in case a previous APK or a restore left
    // a placeholder/test URL in prefs (e.g. exemplo.com, via.placeholder.com).
    // This prevents the app from auto-loading example playlists on startup.
    await _sanitizePlaylistOverrideIfNeeded();
  }

  /// Test helper to reset internal prefs instance across tests
  /// Only intended for use in unit tests to ensure clean state.
  static Future<void> resetForTests() async {
    _prefs = null;
    await init();
  }

  static String? getPlaylistOverride() {
    return _prefs?.getString(keyPlaylistOverride);
  }

  static Future<void> setPlaylistOverride(String? value) async {
    if (_prefs == null) {
      await init();
    }
    if (value == null || value.trim().isEmpty) {
      // CRÍTICO: Remove múltiplas vezes para garantir que foi deletado
      await _prefs!.remove(keyPlaylistOverride);
      await _prefs!.remove(keyPlaylistReady);
      await _prefs!.remove(keyPlaylistLastDownload);
      // Força commit imediato
      await _prefs!.reload();
      // Remove novamente após reload para garantir
      await _prefs!.remove(keyPlaylistOverride);
      await _prefs!.remove(keyPlaylistReady);
      await _prefs!.remove(keyPlaylistLastDownload);
    } else {
      await _prefs!.setString(keyPlaylistOverride, value.trim());
    }
  }

  /// --- TMDB API Key helpers ---
  static String? getTmdbApiKey() {
    return _prefs?.getString(keyTmdbApiKey);
  }

  static Future<void> setTmdbApiKey(String? value) async {
    if (_prefs == null) await init();
    if (value == null || value.trim().isEmpty) {
      await _prefs!.remove(keyTmdbApiKey);
    } else {
      await _prefs!.setString(keyTmdbApiKey, value.trim());
    }
  }

  /// Detects placeholder/example playlist URLs and clears them to avoid
  /// accidental startup with sample data. This is intentionally conservative:
  /// only clears values that match well-known placeholder domains or clearly
  /// invalid example strings.
  static Future<void> _sanitizePlaylistOverrideIfNeeded() async {
    if (_prefs == null) return;
    final v = _prefs!.getString(keyPlaylistOverride);
    if (v == null || v.trim().isEmpty) return;
    final s = v.trim().toLowerCase();
    
    // Known placeholder patterns to clear automatically
    final placeholders = ['exemplo.com', 'example.com', 'via.placeholder.com', 'test.com'];
    for (final p in placeholders) {
      if (s.contains(p)) {
        // Clear persisted playlist override and readiness flags
        await setPlaylistOverride(null);
        print('🧹 Prefs: Detected placeholder playlist "${v}" - cleared automatically.');
        return;
      }
    }
    
    // IMPORTANTE: URLs reais (mesmo que contenham palavras-chave conhecidas) 
    // NÃO são limpas. O usuário configurou, então mantemos.
    print('✅ Prefs: URL configurada pelo usuário detectada - mantendo: ${v.substring(0, v.length > 60 ? 60 : v.length)}...');
  }

  /// Verifica se a playlist foi baixada e está pronta para uso
  static bool isPlaylistReady() {
    return _prefs?.getBool(keyPlaylistReady) ?? false;
  }

  // --- FIRST-RUN HELPERS ---
  static const String keyFirstRunDone = 'first_run_done';

  /// Returns true if this is the very first run of the app (no flag set yet)
  static Future<bool> isFirstRun() async {
    if (_prefs == null) await init();
    final v = _prefs?.getBool(keyFirstRunDone);
    return v == null || v == false;
  }

  /// Marks that the first-run initialization has been completed
  static Future<void> setFirstRunDone() async {
    if (_prefs == null) await init();
    await _prefs!.setBool(keyFirstRunDone, true);
  }

  /// Marca a playlist como pronta (baixada com sucesso)
  static Future<void> setPlaylistReady(bool ready) async {
    if (_prefs == null) await init();
    await _prefs!.setBool(keyPlaylistReady, ready);
    if (ready) {
      await _prefs!.setInt(keyPlaylistLastDownload, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Retorna timestamp do último download
  static DateTime? getLastDownloadTime() {
    final ts = _prefs?.getInt(keyPlaylistLastDownload);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  /// Verifica se a playlist precisa ser atualizada (mais de 24h)
  static bool needsRefresh({Duration maxAge = const Duration(hours: 24)}) {
    final lastDownload = getLastDownloadTime();
    if (lastDownload == null) return true;
    return DateTime.now().difference(lastDownload) > maxAge;
  }
}
