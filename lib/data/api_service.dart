import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/content_item.dart';
import '../models/series_details.dart'; // Agora este arquivo existe!
import '../core/config.dart';

class ApiService {
  static Future<List<String>> fetchCategoryNames(String type) async {
    try {
      final res = await http.get(Uri.parse('${Config.backendUrl}/api/categories?type=$type'));
      if (res.statusCode == 200) return List<String>.from(json.decode(res.body));
    } catch (_) {}
    return [];
  }

  static Future<List<ContentItem>> fetchCategoryItems(String category, String type, {int limit = 15}) async {
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/items?category=${Uri.encodeComponent(category)}&type=$type&page=1&limit=$limit');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<SeriesDetails?> fetchSeriesDetails(String id) async {
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/series/details?id=${Uri.encodeComponent(id)}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return SeriesDetails.fromJson(json.decode(res.body));
      }
    } catch (e) {
      print("Erro ao buscar série: $e");
    }
    return null;
  }

  // Fetch all movies (type: 'movies')
  static Future<List<ContentItem>> fetchAllMovies({int limit = 50}) async {
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/items?type=movies&page=1&limit=$limit');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
    } catch (e) {
      print('Erro ao buscar filmes: $e');
    }
    return [];
  }

  // Fetch all series (type: 'series')
  static Future<List<ContentItem>> fetchAllSeries({int limit = 50}) async {
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/items?type=series&page=1&limit=$limit');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
    } catch (e) {
      print('Erro ao buscar séries: $e');
    }
    return [];
  }

  // Fetch all live channels (type: 'channels')
  static Future<List<ContentItem>> fetchAllChannels({int limit = 50}) async {
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/items?type=channels&page=1&limit=$limit');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
    } catch (e) {
      print('Erro ao buscar canais: $e');
    }
    return [];
  }
}