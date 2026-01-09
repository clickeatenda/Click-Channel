import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para ValueNotifier
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_item.dart';

class FavoritesService {
  static const String _key = 'favorites_list_v1';
  static List<ContentItem> _favorites = []; // Cache em memória
  
  /// Notifier para atualizações reativas na UI
  static final ValueNotifier<List<ContentItem>> favoritesNotifier = ValueNotifier([]);

  /// Inicializa carregando do disco
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _favorites = decoded.map((e) => ContentItem.fromJson(e)).toList();
        favoritesNotifier.value = List.from(_favorites.reversed); // Notifica ouvintes
      } catch (e) {
        print('❌ Erro ao carregar favoritos: $e');
      }
    }
  }

  /// Retorna todos os favoritos ordenados pelos adicionados recentemente
  static List<ContentItem> getAll() {
    return List.from(_favorites.reversed);
  }

  /// Verifica se um item já é favorito
  static bool isFavorite(ContentItem item) {
    // Compara por URL ou Título (para garantir unicidade)
    return _favorites.any((f) => _generateId(f) == _generateId(item));
  }

  /// Alterna o estado de favorito (Adiciona/Remove)
  static Future<void> toggleFavorite(ContentItem item) async {
    if (isFavorite(item)) {
      _favorites.removeWhere((f) => _generateId(f) == _generateId(item));
    } else {
      _favorites.add(item);
    }
    favoritesNotifier.value = List.from(_favorites.reversed); // Notifica ouvintes
    await _saveToDisk();
  }

  /// Gera um ID único para comparação
  static String _generateId(ContentItem item) {
    if (item.url.isNotEmpty) return item.url;
    // Fallback para título + grupo se URL for vazia (ex: itens puramente TMDB)
    return '${item.title}|${item.group}';
  }

  /// Salva a lista atual no disco
  static Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _favorites.map((e) => _toJson(e)).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  /// Converte ContentItem para JSON simplificado para persistência
  static Map<String, dynamic> _toJson(ContentItem item) {
    return {
      'title': item.title,
      'url': item.url,
      'logo': item.image, // ContentItem.fromJson espera 'logo'
      'group': item.group,
      'type': item.type,
      'isSeries': item.isSeries,
      'quality': item.quality,
      'rating': item.rating,
      'year': item.year,
      'description': item.description,
      'genre': item.genre,
    };
  }
}
