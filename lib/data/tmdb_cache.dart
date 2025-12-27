import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'tmdb_service.dart';

/// Cache simples baseado em SharedPreferences.
/// Chave: map de normalizedTitle -> { ts: epochMillis, data: {...tmdb JSON...} }
class TmdbCache {
  static const _prefsKey = 'tmdb_cache_v1';
  static const _defaultTtlDays = 30; // 30 dias

  /// Recupera metadados em cache por chave normalizada. Retorna null se ausente ou expirado.
  static Future<TmdbMetadata?> get(String normalizedKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return null;
      final Map<String, dynamic> map = json.decode(raw) as Map<String, dynamic>;
      if (!map.containsKey(normalizedKey)) return null;
      final entry = map[normalizedKey] as Map<String, dynamic>;
      final ts = (entry['ts'] ?? 0) as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ttlMs = _defaultTtlDays * 24 * 3600 * 1000;
      if (now - ts > ttlMs) {
        // expirado
        map.remove(normalizedKey);
        await prefs.setString(_prefsKey, json.encode(map));
        return null;
      }
      final data = entry['data'] as Map<String, dynamic>;
      return TmdbMetadata.fromCacheJson(data);
    } catch (e) {
      // se algo der errado, apenas não use cache
      return null;
    }
  }

  /// Salva metadados em cache para a chave normalizada
  static Future<void> put(String normalizedKey, TmdbMetadata metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final Map<String, dynamic> map = raw != null ? json.decode(raw) as Map<String, dynamic> : <String, dynamic>{};
      map[normalizedKey] = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': metadata.toCacheJson(),
      };
      await prefs.setString(_prefsKey, json.encode(map));
    } catch (e) {
      // ignora erros de cache
    }
  }

  /// Limpa o cache inteiro
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
