import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_item.dart';

/// Serviço para gerenciar histórico de visualização e progresso
class WatchHistoryService {
  static const String _watchedKey = 'watch_history';
  static const String _watchingKey = 'watching_progress';
  static const int _maxHistoryItems = 50;

  static SharedPreferences? _prefs;

  static Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ============= ÚLTIMOS ASSISTIDOS =============
  
  /// Adiciona um item ao histórico de assistidos
  static Future<void> addToWatched(ContentItem item) async {
    await _ensureInit();
    
    final history = await getWatchedHistory();
    
    // Remove se já existe (para reordenar)
    history.removeWhere((h) => h['url'] == item.url);
    
    // Adiciona no início
    history.insert(0, {
      'title': item.title,
      'url': item.url,
      'image': item.image,
      'group': item.group,
      'type': item.type,
      'isSeries': item.isSeries,
      'quality': item.quality,
      'audioType': item.audioType,
      'watchedAt': DateTime.now().toIso8601String(),
    });
    
    // Limita o tamanho
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await _prefs!.setString(_watchedKey, jsonEncode(history));
  }

  /// Retorna o histórico de assistidos
  static Future<List<Map<String, dynamic>>> getWatchedHistory() async {
    await _ensureInit();
    
    final data = _prefs!.getString(_watchedKey);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Verifica se um item já foi marcado como assistido
  static Future<bool> isWatched(String url) async {
    final history = await getWatchedHistory();
    return history.any((h) => h['url'] == url);
  }


  /// Converte histórico para lista de ContentItem
  static Future<List<ContentItem>> getWatchedItems({int limit = 20}) async {
    final history = await getWatchedHistory();
    
    return history.take(limit).map((h) => ContentItem(
      title: h['title'] ?? '',
      url: h['url'] ?? '',
      image: h['image'] ?? '',
      group: h['group'] ?? '',
      type: h['type'] ?? 'movie',
      isSeries: h['isSeries'] ?? false,
      quality: h['quality'] ?? 'sd',
      audioType: h['audioType'] ?? '',
    )).toList();
  }

  // ============= ASSISTINDO (CONTINUAR) =============
  
  /// Salva progresso de um item (posição em segundos)
  static Future<void> saveProgress(ContentItem item, Duration position, Duration duration) async {
    await _ensureInit();
    
    final watching = await getWatchingProgress();
    
    // Remove se já existe
    watching.removeWhere((w) => w['url'] == item.url);
    
    // Para canais ao vivo (duração 0 ou muito pequena), salva após 30 segundos
    final isLiveChannel = duration.inSeconds <= 0 || item.type == 'channel';
    
    if (isLiveChannel) {
      // Para canais ao vivo: salva após 30 segundos e adiciona aos assistidos
      if (position.inSeconds >= 30) {
        await addToWatched(item);
      }
      return; // Canais ao vivo não ficam em "continuar assistindo"
    }
    
    // Para VOD (filmes/séries): lógica normal
    final progress = duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0;
    if (position.inSeconds < 30 || progress > 0.95) {
      // Se terminou, apenas remove da lista "assistindo"
      if (progress > 0.95) {
        await _prefs!.setString(_watchingKey, jsonEncode(watching));
        // Adiciona aos assistidos
        await addToWatched(item);
      }
      return;
    }
    
    // Adiciona no início
    watching.insert(0, {
      'title': item.title,
      'url': item.url,
      'image': item.image,
      'group': item.group,
      'type': item.type,
      'isSeries': item.isSeries,
      'quality': item.quality,
      'audioType': item.audioType,
      'positionSeconds': position.inSeconds,
      'durationSeconds': duration.inSeconds,
      'progress': progress,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    
    // Limita o tamanho
    if (watching.length > _maxHistoryItems) {
      watching.removeRange(_maxHistoryItems, watching.length);
    }
    
    await _prefs!.setString(_watchingKey, jsonEncode(watching));
  }

  /// Retorna lista de itens em progresso
  static Future<List<Map<String, dynamic>>> getWatchingProgress() async {
    await _ensureInit();
    
    final data = _prefs!.getString(_watchingKey);
    if (data == null || data.isEmpty) return [];
    
    try {
      final list = jsonDecode(data) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Converte progresso para lista de ContentItem com info extra
  static Future<List<WatchingItem>> getWatchingItems({int limit = 20}) async {
    final watching = await getWatchingProgress();
    
    return watching.take(limit).map((w) => WatchingItem(
      item: ContentItem(
        title: w['title'] ?? '',
        url: w['url'] ?? '',
        image: w['image'] ?? '',
        group: w['group'] ?? '',
        type: w['type'] ?? 'movie',
        isSeries: w['isSeries'] ?? false,
        quality: w['quality'] ?? 'sd',
        audioType: w['audioType'] ?? '',
      ),
      positionSeconds: w['positionSeconds'] ?? 0,
      durationSeconds: w['durationSeconds'] ?? 0,
      progress: (w['progress'] ?? 0.0).toDouble(),
    )).toList();
  }

  /// Obtém a posição salva de um item específico
  static Future<Duration?> getSavedPosition(String url) async {
    final watching = await getWatchingProgress();
    
    for (final w in watching) {
      if (w['url'] == url) {
        final seconds = w['positionSeconds'] as int? ?? 0;
        return Duration(seconds: seconds);
      }
    }
    return null;
  }

  /// Remove um item do "assistindo"
  static Future<void> removeFromWatching(String url) async {
    await _ensureInit();
    
    final watching = await getWatchingProgress();
    watching.removeWhere((w) => w['url'] == url);
    await _prefs!.setString(_watchingKey, jsonEncode(watching));
  }

  /// Limpa todo o histórico
  static Future<void> clearAll() async {
    await _ensureInit();
    await _prefs!.remove(_watchedKey);
    await _prefs!.remove(_watchingKey);
  }
}

/// Representa um item em progresso de visualização
class WatchingItem {
  final ContentItem item;
  final int positionSeconds;
  final int durationSeconds;
  final double progress;

  WatchingItem({
    required this.item,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.progress,
  });

  String get formattedPosition {
    final pos = Duration(seconds: positionSeconds);
    final dur = Duration(seconds: durationSeconds);
    return '${_formatDuration(pos)} / ${_formatDuration(dur)}';
  }

  String get remainingTime {
    final remaining = durationSeconds - positionSeconds;
    if (remaining <= 0) return '';
    final dur = Duration(seconds: remaining);
    return 'Faltam ${_formatDuration(dur)}';
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
