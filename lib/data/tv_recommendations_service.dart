import 'package:flutter/services.dart';
import '../models/content_item.dart';
import '../data/watch_history_service.dart';

/// Serviço para integrar o "Continuar Assistindo" do app com a Home do Android TV / Fire TV.
class TvRecommendationsService {
  static const _channel = MethodChannel('com.clickchannel.tv/recommendations');

  /// Atualiza os itens no canal Watch Next do sistema
  static Future<void> updateWatchNext() async {
    try {
      // Pega os itens em progresso (limitado aos 10 primeiros)
      final watchingItems = await WatchHistoryService.getWatchingItems(limit: 10);

      if (watchingItems.isEmpty) {
        await _channel.invokeMethod('clearWatchNext');
        return;
      }

      final List<Map<String, dynamic>> moviesData = [];
      
      for (var watching in watchingItems) {
        final item = watching.item;
        
        moviesData.add({
          'id': item.id,
          'title': item.title,
          'description': item.description,
          'posterUrl': item.image,
          'type': item.type,
          'position': watching.positionSeconds,
          'duration': watching.durationSeconds,
        });
      }

      await _channel.invokeMethod('updateWatchNext', {'movies': moviesData});
      print('📺 TV Recommendations: Sincronizado com a Home (${moviesData.length} itens)');
    } catch (e) {
      print('❌ Erro ao sincronizar recomendações de TV: $e');
    }
  }

  /// Limpa as recomendações da Home
  static Future<void> clearAll() async {
    try {
      await _channel.invokeMethod('clearWatchNext');
    } catch (e) {
      print('❌ Erro ao limpar recomendações de TV: $e');
    }
  }
}
