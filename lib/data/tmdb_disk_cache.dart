import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'tmdb_service.dart';

/// Cache de metadados TMDB em disco (arquivo JSON). Mantém map normalizedKey -> { ts, data }
class TmdbDiskCache {
  static const _fileName = 'tmdb_cache.json';

  static Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return {};
      final Map<String, dynamic> map = json.decode(raw) as Map<String, dynamic>;
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAll(Map<String, dynamic> map) async {
    try {
      final f = await _cacheFile();
      await f.writeAsString(json.encode(map), flush: true);
    } catch (_) {}
  }

  static Future<TmdbMetadata?> get(String normalizedKey) async {
    try {
      final map = await _readAll();
      if (!map.containsKey(normalizedKey)) return null;
      final entry = map[normalizedKey] as Map<String, dynamic>;
      final ts = (entry['ts'] ?? 0) as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      const ttlMs = 30 * 24 * 3600 * 1000; // 30 dias
      if (now - ts > ttlMs) {
        map.remove(normalizedKey);
        await _writeAll(map);
        return null;
      }
      final data = entry['data'] as Map<String, dynamic>;
      return TmdbMetadata.fromCacheJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String normalizedKey, TmdbMetadata metadata) async {
    try {
      final map = await _readAll();
      map[normalizedKey] = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': metadata.toCacheJson(),
      };
      await _writeAll(map);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final f = await _cacheFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
