import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/content_item.dart';
import '../models/series_details.dart'; // Agora este arquivo existe!
import '../core/config.dart';

class ApiService {
  static Future<List<String>> fetchCategoryNames(String type) async {
    // Front-only mode: no backend calls.
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchCategoryNames("$type") retornando lista vazia');
      return [];
    }
    try {
      final url = '${Config.backendUrl}/api/categories?type=$type';
      print('🔗 Fetching categories from: $url');
      final res = await http.get(Uri.parse(url));
      print('📡 Status: ${res.statusCode}');
      if (res.statusCode == 200) return List<String>.from(json.decode(res.body));
      print('❌ Error: ${res.statusCode} - ${res.body}');
    } catch (e) {
      print('❌ Exception: $e');
    }
    return [];
  }

  static Future<List<ContentItem>> fetchCategoryItems(String category, String type, {int limit = 15}) async {
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchCategoryItems(category=$category, type=$type) retornando lista vazia');
      return [];
    }
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
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchSeriesDetails(id=$id) retornando null');
      return null;
    }
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

  // Fetch all movies - precisa de uma categoria para funcionar
  static Future<List<ContentItem>> fetchAllMovies({int limit = 50}) async {
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchAllMovies(limit=$limit) retornando lista vazia');
      return [];
    }
    try {
      // Primeiro buscar categorias de filmes
      final baseUrl = Config.backendUrl;
      print('🎬 [fetchAllMovies] Step 1: Buscando categorias...');
      
      final categories = await fetchCategoryNames('');
      if (categories.isEmpty) {
        print('⚠️ [fetchAllMovies] Nenhuma categoria encontrada');
        return [];
      }
      
      print('🎬 [fetchAllMovies] Step 2: Encontradas ${categories.length} categorias');
      print('🎬 [fetchAllMovies] Primeira categoria: ${categories.first}');
      
      // Buscar itens da primeira categoria
      final uri = Uri.parse('$baseUrl/api/items?category=${Uri.encodeComponent(categories.first)}&page=1&limit=$limit');
      print('🎬 [fetchAllMovies] Step 3: Tentando conectar em: $uri');
      
      final res = await http.get(uri).timeout(const Duration(seconds: 10), onTimeout: () {
        print('❌ [fetchAllMovies] TIMEOUT: Sem resposta do servidor em 10s');
        throw Exception('Timeout ao conectar com backend');
      });
      
      print('📡 [fetchAllMovies] Status: ${res.statusCode}');
      print('📡 [fetchAllMovies] Response length: ${res.body.length} bytes');
      print('📡 [fetchAllMovies] Response body: ${res.body.substring(0, min(500, res.body.length))}');
      
      if (res.statusCode == 200) {
        if (res.body.isEmpty) {
          print('⚠️ [fetchAllMovies] Resposta vazia do servidor!');
          return [];
        }
        
        List list = json.decode(res.body);
        print('📦 [fetchAllMovies] Total de itens recebidos: ${list.length}');
        
        if (list.isEmpty) {
          print('⚠️ [fetchAllMovies] Backend retornou array vazio');
          return [];
        }
        
        // Filtrar apenas itens que não são séries
        final movies = list.where((item) {
          try {
            final contentItem = ContentItem.fromJson(item);
            return !contentItem.isSeries;
          } catch (e) {
            print('⚠️ [fetchAllMovies] Erro ao parsear item: $e');
            return false;
          }
        }).toList();
        
        print('✅ [fetchAllMovies] Got ${movies.length} filmes/canais de ${list.length} totais');
        return movies.map((i) => ContentItem.fromJson(i)).toList();
      }
      
      print('❌ [fetchAllMovies] HTTP Error: ${res.statusCode} - ${res.body.substring(0, min(200, res.body.length))}');
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    } on SocketException catch (e) {
      print('❌ [fetchAllMovies] CONEXÃO RECUSADA: $e');
      print('❌ [fetchAllMovies] Verifique se o backend está rodando em ${Config.backendUrl}');
      throw Exception('Conexão recusada. Backend em ${Config.backendUrl} está offline?');
    } catch (e) {
      print('❌ [fetchAllMovies] Exception: $e');
      rethrow;
    }
  }

  // Fetch all series (type: 'series')
  static Future<List<ContentItem>> fetchAllSeries({int limit = 50}) async {
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchAllSeries(limit=$limit) retornando lista vazia');
      return [];
    }
    try {
      // Backend requer category, então primeiro busca as categorias
      final baseUrl = Config.backendUrl;
      print('📺 [fetchAllSeries] Step 1: Buscando categorias de séries...');
      
      final categories = await fetchCategoryNames('series');
      if (categories.isEmpty) {
        print('⚠️ [fetchAllSeries] Nenhuma categoria de série encontrada');
        return [];
      }
      
      print('📺 [fetchAllSeries] Step 2: Encontradas ${categories.length} categorias');
      print('📺 [fetchAllSeries] Primeira categoria: ${categories.first}');
      
      // Busca itens da primeira categoria como exemplo
      final uri = Uri.parse('$baseUrl/api/items?category=${Uri.encodeComponent(categories.first)}&type=series&page=1&limit=$limit');
      print('📺 [fetchAllSeries] Step 3: Fetching series from: $uri');
      
      final res = await http.get(uri).timeout(const Duration(seconds: 10), onTimeout: () {
        print('❌ [fetchAllSeries] TIMEOUT: Sem resposta do servidor em 10s');
        throw Exception('Timeout ao conectar com backend');
      });
      
      print('📡 [fetchAllSeries] Status: ${res.statusCode}');
      
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        print('✅ [fetchAllSeries] Got ${list.length} series');
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
      print('❌ [fetchAllSeries] HTTP Error: ${res.statusCode} - ${res.body.substring(0, min(200, res.body.length))}');
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    } on SocketException catch (e) {
      print('❌ [fetchAllSeries] CONEXÃO RECUSADA: $e');
      throw Exception('Conexão recusada. Backend offline?');
    } catch (e) {
      print('❌ [fetchAllSeries] Exception: $e');
      rethrow;
    }
  }

  // Fetch all live channels (type: 'channels')
  static Future<List<ContentItem>> fetchAllChannels({int limit = 50}) async {
    if (Config.frontOnly) {
      print('⚙️ FRONT-ONLY: fetchAllChannels(limit=$limit) retornando lista vazia');
      return [];
    }
    try {
      final uri = Uri.parse('${Config.backendUrl}/api/items?type=channels&limit=$limit');
      print('📡 Fetching channels from: $uri');
      final res = await http.get(uri);
      print('📡 Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        List list = json.decode(res.body);
        print('✅ Got ${list.length} channels');
        return list.map((i) => ContentItem.fromJson(i)).toList();
      }
      print('❌ Error: ${res.statusCode} - ${res.body}');
    } catch (e) {
      print('❌ Exception: $e');
    }
    return [];
  }
}