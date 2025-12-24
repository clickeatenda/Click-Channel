import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../models/epg_program.dart';

/// Serviço para gerenciar EPG (Electronic Program Guide)
/// Suporta formato XMLTV
class EpgService {
  static Map<String, EpgChannel> _channelsCache = {};
  static DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(hours: 6);
  static String? _epgUrl;
  
  // Programas favoritos para notificação
  static Set<String> _favoritePrograms = {};
  static const String _favoritesKey = 'epg_favorite_programs';

  /// URL do EPG hardcoded (fallback se não configurada)
  static const String _hardcodedEpgUrl = 'https://epg.pw/xmltv/epg_BR.xml';

  /// Define a URL do EPG
  static void setEpgUrl(String url) {
    _epgUrl = url;
  }

  /// Obtém a URL do EPG salva (usa hardcoded se disponível)
  static String? get epgUrl => _epgUrl ?? _hardcodedEpgUrl;

  /// Carrega e parseia o EPG de uma URL XMLTV
  static Future<void> loadEpg(String url, {void Function(double, String)? onProgress}) async {
    try {
      onProgress?.call(0.1, 'Baixando EPG...');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 60),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Erro ao baixar EPG: ${response.statusCode}');
      }

      onProgress?.call(0.4, 'Processando EPG...');
      
      final xmlContent = response.body;
      
      // Parsear em isolate para não travar a UI
      final channels = await compute(_parseXmltvInIsolate, xmlContent);
      
      _channelsCache = channels;
      _lastFetch = DateTime.now();
      _epgUrl = url;
      
      // Salvar URL nas preferências
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('epg_url', url);
      
      // Salvar cache em disco
      await _saveCacheToDisk(xmlContent);
      
      onProgress?.call(1.0, 'EPG carregado!');
      
      print('✅ EPG: Carregados ${_channelsCache.length} canais');
    } catch (e) {
      print('❌ EPG: Erro ao carregar: $e');
      rethrow;
    }
  }

  /// Parseia XMLTV em isolate
  static Map<String, EpgChannel> _parseXmltvInIsolate(String xmlContent) {
    return _parseXmltv(xmlContent);
  }

  /// Parser de XMLTV
  static Map<String, EpgChannel> _parseXmltv(String xmlContent) {
    final Map<String, EpgChannel> channels = {};
    final Map<String, List<EpgProgram>> programsByChannel = {};
    final Map<String, String> channelNames = {};
    final Map<String, String?> channelIcons = {};

    try {
      // Parser simplificado de XML usando RegExp
      // Para produção, considerar usar xml package
      
      // Extrair canais
      final channelRegex = RegExp(
        r'<channel\s+id="([^"]+)"[^>]*>(.*?)</channel>',
        dotAll: true,
      );
      
      for (final match in channelRegex.allMatches(xmlContent)) {
        final channelId = match.group(1) ?? '';
        final channelContent = match.group(2) ?? '';
        
        // Extrair nome do canal
        final nameMatch = RegExp(r'<display-name[^>]*>([^<]+)</display-name>')
            .firstMatch(channelContent);
        final displayName = nameMatch?.group(1) ?? channelId;
        
        // Extrair ícone
        final iconMatch = RegExp(r'<icon\s+src="([^"]+)"')
            .firstMatch(channelContent);
        final icon = iconMatch?.group(1);
        
        channelNames[channelId] = _decodeHtmlEntities(displayName);
        channelIcons[channelId] = icon;
        programsByChannel[channelId] = [];
      }

      // Extrair programas - regex flexível para aceitar atributos em qualquer ordem
      final programRegex = RegExp(
        r'<programme([^>]*)>(.*?)</programme>',
        dotAll: true,
      );

      for (final match in programRegex.allMatches(xmlContent)) {
        final attributes = match.group(1) ?? '';
        final programContent = match.group(2) ?? '';
        
        // Extrair atributos individualmente
        final startMatch = RegExp(r'start="([^"]+)"').firstMatch(attributes);
        final stopMatch = RegExp(r'stop="([^"]+)"').firstMatch(attributes);
        final channelMatch = RegExp(r'channel="([^"]+)"').firstMatch(attributes);
        
        final startStr = startMatch?.group(1) ?? '';
        final stopStr = stopMatch?.group(1) ?? '';
        final channelId = channelMatch?.group(1) ?? '';
        
        if (startStr.isEmpty || stopStr.isEmpty || channelId.isEmpty) continue;

        // Parsear datas XMLTV (formato: 20231217120000 +0000)
        final start = _parseXmltvDate(startStr);
        final stop = _parseXmltvDate(stopStr);
        
        if (start == null || stop == null) continue;

        // Extrair título
        final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>')
            .firstMatch(programContent);
        final title = titleMatch?.group(1) ?? 'Sem título';

        // Extrair descrição
        final descMatch = RegExp(r'<desc[^>]*>([^<]+)</desc>')
            .firstMatch(programContent);
        final description = descMatch?.group(1);

        // Extrair categoria
        final catMatch = RegExp(r'<category[^>]*>([^<]+)</category>')
            .firstMatch(programContent);
        final category = catMatch?.group(1);

        // Extrair ícone do programa
        final iconMatch = RegExp(r'<icon\s+src="([^"]+)"')
            .firstMatch(programContent);
        final icon = iconMatch?.group(1);

        // Extrair rating
        final ratingMatch = RegExp(r'<rating[^>]*>.*?<value>([^<]+)</value>')
            .firstMatch(programContent);
        final rating = ratingMatch?.group(1);

        // Extrair número do episódio
        final episodeMatch = RegExp(r'<episode-num[^>]*>([^<]+)</episode-num>')
            .firstMatch(programContent);
        final episodeNum = episodeMatch?.group(1);

        final program = EpgProgram(
          channelId: channelId,
          title: _decodeHtmlEntities(title),
          description: description != null ? _decodeHtmlEntities(description) : null,
          start: start,
          end: stop,
          category: category != null ? _decodeHtmlEntities(category) : null,
          icon: icon,
          rating: rating,
          episodeNum: episodeNum,
        );

        programsByChannel.putIfAbsent(channelId, () => []);
        programsByChannel[channelId]!.add(program);
      }

      // Montar objetos EpgChannel
      for (final channelId in channelNames.keys) {
        final programs = programsByChannel[channelId] ?? [];
        programs.sort((a, b) => a.start.compareTo(b.start));
        
        channels[channelId] = EpgChannel(
          id: channelId,
          displayName: channelNames[channelId]!,
          icon: channelIcons[channelId],
          programs: programs,
        );
      }

      print('📺 EPG Parser: ${channels.length} canais, ${programsByChannel.values.fold(0, (sum, list) => sum + list.length)} programas');
      
    } catch (e) {
      print('❌ EPG Parser Error: $e');
    }

    return channels;
  }

  /// Parseia data no formato XMLTV
  static DateTime? _parseXmltvDate(String dateStr) {
    try {
      // Formato: 20231217120000 +0000 ou 20231217120000
      final cleanDate = dateStr.replaceAll(RegExp(r'\s.*'), '');
      if (cleanDate.length < 14) return null;

      final year = int.parse(cleanDate.substring(0, 4));
      final month = int.parse(cleanDate.substring(4, 6));
      final day = int.parse(cleanDate.substring(6, 8));
      final hour = int.parse(cleanDate.substring(8, 10));
      final minute = int.parse(cleanDate.substring(10, 12));
      final second = int.parse(cleanDate.substring(12, 14));

      // Extrair timezone se existir
      final tzMatch = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(dateStr);
      if (tzMatch != null) {
        final sign = tzMatch.group(1) == '+' ? 1 : -1;
        final tzHours = int.parse(tzMatch.group(2)!);
        final tzMinutes = int.parse(tzMatch.group(3)!);
        final offset = Duration(hours: tzHours * sign, minutes: tzMinutes * sign);
        return DateTime.utc(year, month, day, hour, minute, second).subtract(offset).toLocal();
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }

  /// Decodifica entidades HTML
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
  }

  /// Salva cache em disco
  static Future<void> _saveCacheToDisk(String xmlContent) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/epg_cache.xml');
      await file.writeAsString(xmlContent);
      print('💾 EPG: Cache salvo em disco');
    } catch (e) {
      print('⚠️ EPG: Erro ao salvar cache: $e');
    }
  }

  /// Carrega cache do disco
  static Future<bool> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _epgUrl = prefs.getString('epg_url');
      
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/epg_cache.xml');
      
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age < _cacheDuration) {
          final xmlContent = await file.readAsString();
          _channelsCache = await compute(_parseXmltvInIsolate, xmlContent);
          _lastFetch = stat.modified;
          print('✅ EPG: Carregado do cache (${_channelsCache.length} canais)');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ EPG: Erro ao carregar cache: $e');
      return false;
    }
  }

  /// Obtém EPG de um canal pelo ID
  static EpgChannel? getChannel(String channelId) {
    return _channelsCache[channelId];
  }

  /// Busca canal por nome (fuzzy match)
  static EpgChannel? findChannelByName(String channelName) {
    final normalizedName = channelName.toLowerCase().trim();
    
    // Tenta match exato primeiro
    for (final channel in _channelsCache.values) {
      if (channel.displayName.toLowerCase() == normalizedName) {
        return channel;
      }
    }
    
    // Tenta match parcial
    for (final channel in _channelsCache.values) {
      if (channel.displayName.toLowerCase().contains(normalizedName) ||
          normalizedName.contains(channel.displayName.toLowerCase())) {
        return channel;
      }
    }
    
    // Tenta match por ID
    for (final channel in _channelsCache.values) {
      if (channel.id.toLowerCase().contains(normalizedName)) {
        return channel;
      }
    }
    
    return null;
  }

  /// Obtém programa atual de um canal
  static EpgProgram? getCurrentProgram(String channelId) {
    return _channelsCache[channelId]?.currentProgram;
  }

  /// Obtém próximo programa de um canal
  static EpgProgram? getNextProgram(String channelId) {
    return _channelsCache[channelId]?.nextProgram;
  }

  /// Obtém todos os canais
  static List<EpgChannel> getAllChannels() {
    return _channelsCache.values.toList();
  }

  /// Verifica se o EPG está carregado
  static bool get isLoaded => _channelsCache.isNotEmpty;

  /// Verifica se precisa atualizar
  static bool get needsRefresh {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  /// Limpa o cache
  static Future<void> clearCache() async {
    _channelsCache.clear();
    _lastFetch = null;
    _epgUrl = null;
    
    // Limpa preferências
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('epg_url');
    
    // Remove arquivo de cache
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheFile = File('${dir.path}/epg_cache.xml');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {}
  }

  // ==================== FAVORITOS ====================

  /// Carrega favoritos salvos
  static Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favoritesKey) ?? [];
      _favoritePrograms = list.toSet();
    } catch (e) {
      print('⚠️ EPG: Erro ao carregar favoritos: $e');
    }
  }

  /// Adiciona programa aos favoritos
  static Future<void> addFavorite(String programId) async {
    _favoritePrograms.add(programId);
    await _saveFavorites();
  }

  /// Remove programa dos favoritos
  static Future<void> removeFavorite(String programId) async {
    _favoritePrograms.remove(programId);
    await _saveFavorites();
  }

  /// Verifica se programa é favorito
  static bool isFavorite(String programId) {
    return _favoritePrograms.contains(programId);
  }

  /// Gera ID único para programa
  static String getProgramId(EpgProgram program) {
    return '${program.channelId}_${program.start.millisecondsSinceEpoch}';
  }

  /// Salva favoritos
  static Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoritePrograms.toList());
    } catch (e) {
      print('⚠️ EPG: Erro ao salvar favoritos: $e');
    }
  }

  /// Obtém programas favoritos que vão começar em breve
  static List<EpgProgram> getUpcomingFavorites({Duration within = const Duration(minutes: 30)}) {
    final List<EpgProgram> upcoming = [];
    final now = DateTime.now();
    final limit = now.add(within);

    for (final channel in _channelsCache.values) {
      for (final program in channel.programs) {
        final programId = getProgramId(program);
        if (_favoritePrograms.contains(programId) &&
            program.start.isAfter(now) &&
            program.start.isBefore(limit)) {
          upcoming.add(program);
        }
      }
    }

    upcoming.sort((a, b) => a.start.compareTo(b.start));
    return upcoming;
  }
}
