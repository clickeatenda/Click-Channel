import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _prefs;

  static const String keyPlaylistOverride = 'playlist_url_override';
  static const String keyPlaylistReady = 'playlist_ready';
  static const String keyPlaylistLastDownload = 'playlist_last_download';

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? getPlaylistOverride() {
    return _prefs?.getString(keyPlaylistOverride);
  }

  static Future<void> setPlaylistOverride(String? value) async {
    if (_prefs == null) {
      await init();
    }
    if (value == null || value.trim().isEmpty) {
      await _prefs!.remove(keyPlaylistOverride);
      // Limpa status também quando URL é removida
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
