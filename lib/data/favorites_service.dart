import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_item.dart';

class FavoritesService {
  static const String KEY_FAVORITES = 'favorites_list';
  
  static Future<List<ContentItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(KEY_FAVORITES);
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ContentItem.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> toggleFavorite(ContentItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<ContentItem> favorites = await getFavorites();
    
    final index = favorites.indexWhere((i) => i.url == item.url);
    
    if (index >= 0) {
        favorites.removeAt(index);
    } else {
        favorites.add(item);
    }
    
    final jsonList = favorites.map((i) => i.toJson()).toList();
    await prefs.setString(KEY_FAVORITES, jsonEncode(jsonList));
  }
  
  static Future<bool> isFavorite(ContentItem item) async {
      final favorites = await getFavorites();
      return favorites.any((i) => i.url == item.url);
  }
}
