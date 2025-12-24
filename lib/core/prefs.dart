import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _prefs;

  static const String keyPlaylistOverride = 'playlist_url_override';
  static const String keyPlaylistReady = 'playlist_ready';
  static const String keyPlaylistLastDownload = 'playlist_last_download';

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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
