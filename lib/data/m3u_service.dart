import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../models/content_item.dart';
import '../models/series_details.dart';

/// Serviço para ler e normalizar playlists M3U diretamente no app (opção B).
/// Suporta tanto URL (HTTP/HTTPS) quanto caminho de arquivo local (file:// ou caminho absoluto).
class M3uService {
  static List<ContentItem>? _movieCache = [];
  static List<ContentItem>? _seriesCache = [];
  static List<ContentItem>? _channelCache = [];
  static String? _movieCacheSource;
  static int _movieCacheMaxItems = 0;
  static Map<String, int> _movieCategoryCounts = {};
  static List<String> _movieCategories = [];
  static Map<String, String> _movieCategoryThumb = {};
  static Map<String, int> _seriesCategoryCounts = {};
  static List<String> _seriesCategories = [];
  static Map<String, String> _seriesCategoryThumb = {};
  static Map<String, int> _channelCategoryCounts = {};
  static List<String> _channelCategories = [];
  static Map<String, String> _channelCategoryThumb = {};
  static Map<String, List<String>>? _curatedFeaturedCache;
  static DateTime? _curatedFeaturedFetchedAt;
  static final Map<String, Future<void>> _pendingCacheEnsures = {};
  static const Duration _cacheTtl = Duration(hours: 12);
  
  // Flag para indicar que preload foi feito
  static bool _preloadDone = false;
  static String? _preloadSource;
  
  // Proteção contra requisições duplicadas simultâneas
  static final Map<String, Future<List<String>>> _pendingRequests = {};

  /// Verifica se o preload já foi feito para a source atual
  static bool isPreloaded(String source) => _preloadDone && _preloadSource == source;

  /// Limpa todos os caches em memória para forçar reload
  static void clearMemoryCache() {
    _movieCache = null;
    _seriesCache = null;
    _channelCache = null;
    _movieCacheSource = null;
    _movieCacheMaxItems = 0;
    _movieCategories.clear();
    _movieCategoryCounts.clear();
    _movieCategoryThumb.clear();
    _seriesCategories.clear();
    _seriesCategoryCounts.clear();
    _seriesCategoryThumb.clear();
    _channelCategories.clear();
    _channelCategoryCounts.clear();
    _channelCategoryThumb.clear();
    _preloadDone = false;
    _preloadSource = null;
    _curatedFeaturedCache = null;
    _curatedFeaturedFetchedAt = null;
    print('🗑️ M3uService: Cache em memória limpo');
  }
  
  /// Limpa TODOS os caches (memória E disco) para forçar download completo
  static Future<void> clearAllCache(String? newSource) async {
    // Limpa memória
    clearMemoryCache();
    
    // Limpa TODOS os arquivos de cache M3U no disco
    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('m3u_cache_')) {
          await file.delete();
          print('🗑️ M3uService: Cache deletado: ${file.path}');
        }
      }
      print('🗑️ M3uService: Todos os caches de disco limpos');
    } catch (e) {
      print('⚠️ M3uService: Erro ao deletar caches de disco: $e');
    }
  }

  /// Retorna true se existe ao menos um arquivo de cache M3U no disco
  static bool Function()? _testHasAnyCache;
  static void setTestHasAnyCache(bool Function()? f) => _testHasAnyCache = f;

  static Future<bool> hasAnyCache() async {
    // Test override for unit tests
    if (_testHasAnyCache != null) {
      try {
        return _testHasAnyCache!();
      } catch (e) {
        print('⚠️ M3uService: test override error: $e');
      }
    }

    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('m3u_cache_')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ M3uService: Erro ao verificar caches de disco: $e');
      return false;
    }
  }

  /// Install marker helpers: used to detect a fresh install run so that we can
  /// avoid auto-loading restored prefs/caches on first open after a fresh install
  static Future<File> _getInstallMarkerFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/install_marker');
  }

  /// Returns whether the install marker file exists
  static Future<bool> hasInstallMarker() async {
    try {
      final file = await _getInstallMarkerFile();
      return await file.exists();
    } catch (e) {
      print('⚠️ M3uService: Erro ao verificar install marker: $e');
      return false;
    }
  }

  /// Write the install marker file (used after performing first-run cleanup)
  static Future<void> writeInstallMarker() async {
    try {
      final file = await _getInstallMarkerFile();
      await file.writeAsString(DateTime.now().toIso8601String(), flush: true);
      print('✅ M3uService: Install marker gravado: ${file.path}');
    } catch (e) {
      print('⚠️ M3uService: Erro ao gravar install marker: $e');
    }
  }

  // ============= MÉTODOS PARA SETUP SCREEN =============
  
  /// Verifica se existe cache local válido para a URL
  static Future<bool> hasCachedPlaylist(String source) async {
    try {
      final file = await _getCacheFile(source);
      print('🔍 M3uService: Verificando cache em: ${file.path}');
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        print('🔍 M3uService: Cache existe, idade: ${age.inMinutes} minutos (TTL: ${_cacheTtl.inMinutes} minutos)');
        // Cache válido se menor que TTL
        if (age < _cacheTtl) {
          print('✅ M3uService: Cache válido!');
          return true;
        } else {
          print('⚠️ M3uService: Cache expirado');
          return false;
        }
      }
      print('❌ M3uService: Arquivo de cache não existe');
      return false;
    } catch (e) {
      print('❌ M3uService: Erro ao verificar cache: $e');
      return false;
    }
  }

  /// Retorna o arquivo de cache para uma URL
  static Future<File> _getCacheFile(String source) async {
    final dir = await getApplicationSupportDirectory();
    final safe = source.hashCode;
    return File('${dir.path}/m3u_cache_$safe.m3u');
  }

  /// Baixa e salva a playlist com callback de progresso
  static Future<void> downloadAndCachePlaylist(
    String source, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!source.startsWith('http')) {
      throw Exception('URL inválida. Deve começar com http:// ou https://');
    }

    // Fix: Se usar HTTPS com porta 80, troca para HTTP
    String fixedSource = source;
    if (source.startsWith('https://') && source.contains(':80')) {
      fixedSource = source.replaceFirst('https://', 'http://');
      print('⚠️ M3uService: Convertendo HTTPS:80 para HTTP:80 -> $fixedSource');
    }

    final client = http.Client();
    IOSink? fileSink;
    try {
      onProgress?.call(0.05, 'Conectando ao servidor...');
      
      final request = http.Request('GET', Uri.parse(fixedSource));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Erro HTTP ${response.statusCode}');
      }

      onProgress?.call(0.1, 'Baixando playlist...');

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      int lineCount = 0;

      // Streaming direto para arquivo - não acumula na memória
      final file = await _getCacheFile(source);
      fileSink = file.openWrite();

      await for (final chunk in response.stream) {
        // Escreve direto no arquivo
        fileSink.add(chunk);
        received += chunk.length;
        
        // Conta linhas aproximadamente (cada \n)
        for (final byte in chunk) {
          if (byte == 10) lineCount++; // 10 = '\n'
        }
        
        if (contentLength > 0) {
          final downloadProgress = received / contentLength;
          onProgress?.call(
            0.1 + (downloadProgress * 0.7), // 10% a 80%
            'Baixando... ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
          );
        } else {
          onProgress?.call(
            0.4,
            'Baixando... ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
          );
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      print('💾 M3uService: Playlist salva em ${file.path} (~$lineCount linhas, ${(received / 1024 / 1024).toStringAsFixed(1)} MB)');
      onProgress?.call(0.85, 'Playlist salva com sucesso!');

    } finally {
      if (fileSink != null) {
        try { await fileSink.close(); } catch (_) {}
      }
      client.close();
    }
  }

  /// Pré-carrega categorias para primeira abertura rápida
  static Future<void> preloadCategories(String source) async {
    // Se já fez preload para essa source, não refaz
    if (_preloadDone && _preloadSource == source) {
      print('♻️ M3uService: Preload já feito para essa source');
      return;
    }
    
    try {
      // Carrega linhas do cache local
      final file = await _getCacheFile(source);
      if (!await file.exists()) {
        print('⚠️ M3uService: Cache não encontrado para preload');
        return;
      }

      print('📦 M3uService: Iniciando preload de $source...');
      
      // Lê TODAS as linhas - sem limite
      final lines = <String>[];
      int lineCount = 0;
      
      await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
        lines.add(line);
        lineCount++;
      }

      print('📦 M3uService: Leu $lineCount linhas, parseando...');
      
      // Debug: mostra primeiras linhas do arquivo
      if (lines.length >= 5) {
        print('📝 Linha 0: ${lines[0].substring(0, lines[0].length > 100 ? 100 : lines[0].length)}');
        print('📝 Linha 1: ${lines[1].substring(0, lines[1].length > 100 ? 100 : lines[1].length)}');
        print('📝 Linha 2: ${lines[2].substring(0, lines[2].length > 100 ? 100 : lines[2].length)}');
      }

      // Parse em isolate - SEM LIMITE para capturar TODO o conteúdo
      final parsedMaps = await compute(_parseLinesIsolate, {'lines': lines, 'limit': 999999});
      
      print('📦 M3uService: Parse retornou ${parsedMaps.length} itens');
      
      // Debug: mostra tipos dos primeiros itens
      int mc = 0, sc = 0, cc = 0;
      for (final m in parsedMaps) {
        if (m['type'] == 'movie') mc++;
        else if (m['type'] == 'series') sc++;
        else cc++;
      }
      print('📊 Breakdown antes de cache: $mc filmes, $sc séries, $cc canais');
      
      final items = parsedMaps.map((m) => ContentItem(
        title: m['title'] ?? '',
        url: m['url'] ?? '',
        image: m['image'] ?? '',
        group: m['group'] ?? 'Geral',
        type: m['type'] ?? 'movie',
        quality: m['quality'] ?? 'sd',
        audioType: m['audioType'] ?? '',
      )).toList();
      
      // Separa por tipo
      final movieItems = items.where((i) => i.type == 'movie').toList();
      final seriesItems = items.where((i) => i.type == 'series').toList();
      final channelItems = items.where((i) => i.type != 'movie' && i.type != 'series').toList();

      // Cacheia os items para uso imediato na Home
      _movieCache = movieItems;
      _seriesCache = seriesItems;
      _channelCache = channelItems;
      _movieCacheSource = source;
      _movieCacheMaxItems = 999999;

      // Extrai categorias
      _extractCategories(movieItems, _movieCategories, _movieCategoryCounts, _movieCategoryThumb);
      _extractCategories(seriesItems, _seriesCategories, _seriesCategoryCounts, _seriesCategoryThumb);
      _extractCategories(channelItems, _channelCategories, _channelCategoryCounts, _channelCategoryThumb);

      // Debug: mostra alguns exemplos de cada tipo
      if (movieItems.isNotEmpty) {
        print('🎬 Exemplo de FILME: ${movieItems.first.title} (grupo: ${movieItems.first.group})');
      }
      if (seriesItems.isNotEmpty) {
        print('📺 Exemplo de SÉRIE: ${seriesItems.first.title} (grupo: ${seriesItems.first.group})');
      }
      if (channelItems.isNotEmpty) {
        print('📡 Exemplo de CANAL: ${channelItems.first.title} (grupo: ${channelItems.first.group})');
      }

      // Marca preload como feito
      _preloadDone = true;
      _preloadSource = source;

      print('✅ M3uService: Preload concluído - ${movieItems.length} filmes, ${seriesItems.length} séries, ${channelItems.length} canais');
      print('✅ M3uService: ${_movieCategories.length} cat filmes, ${_seriesCategories.length} cat séries');
    } catch (e) {
      print('⚠️ M3uService: Erro no preload: $e');
    }
  }

  /// Extrai categorias de uma lista de items
  static void _extractCategories(
    List<ContentItem> items,
    List<String> categories,
    Map<String, int> counts,
    Map<String, String> thumbs,
  ) {
    categories.clear();
    counts.clear();
    thumbs.clear();
    
    final seen = <String>{};
    for (final item in items) {
      final group = item.group;
      if (group.isNotEmpty && !seen.contains(group)) {
        seen.add(group);
        categories.add(group);
        counts[group] = 0;
        if (item.image.isNotEmpty) {
          thumbs[group] = item.image;
        }
      }
      if (counts.containsKey(group)) {
        counts[group] = (counts[group] ?? 0) + 1;
      }
    }
  }

  // ============= MÉTODOS ORIGINAIS =============

  /// Lê a playlist definida em `.env` via `M3U_PLAYLIST_URL`.
  /// Quando `limit` é informado, corta a lista após o número desejado de itens
  /// para evitar estourar memória/renderização.
  static Future<List<ContentItem>> fetchFromEnv({int limit = 500}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      throw Exception('M3U_PLAYLIST_URL não definido no .env');
    }
    return parse(source: source, limit: limit);
  }

  /// Faz o parse de uma playlist M3U a partir de uma URL ou caminho local.
  /// - Se começar com `http`, baixa via streaming HTTP.
  /// - Se for caminho de arquivo ou `file://`, lê via File().openRead().
  static Future<List<ContentItem>> parse({required String source, int limit = 500}) async {
    final lines = await _loadLines(source);
    return _parseLines(lines, limit: limit);
  }

  /// Carregamento paginado para filmes (somente front). Faz cache em memória e
  /// retorna fatias de `pageSize` para não estourar memória/renderização.
  static Future<M3uPagedResult> fetchPagedFromEnv({
    int page = 1,
    int pageSize = 80,
    int maxItems = 999999,
    String typeFilter = 'movie',
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      throw Exception('M3U_PLAYLIST_URL não definido no .env');
    }

    if (typeFilter != 'movie') {
      // Por enquanto, apenas filmes são suportados no cache paginado
      throw Exception('fetchPagedFromEnv suporta apenas filmes no momento');
    }

    await _ensureMovieCache(source: source, maxItems: maxItems);

    final total = _movieCache?.length ?? 0;
    final start = (page - 1) * pageSize;
    if (start >= total) {
      return M3uPagedResult(items: const [], total: total, categories: _movieCategories, categoryCounts: _movieCategoryCounts);
    }
    final end = (start + pageSize) > total ? total : (start + pageSize);
    final slice = _movieCache!.sublist(start, end);

    return M3uPagedResult(
      items: slice,
      total: total,
      categories: _movieCategories,
      categoryCounts: _movieCategoryCounts,
    );
  }

  // --- helpers ---

  static Future<List<String>> _loadLines(String source) async {
    // Se já existe uma requisição em andamento para esta source, reutiliza
    if (_pendingRequests.containsKey(source)) {
      print('♻️ M3uService: Reutilizando requisição em andamento para: $source');
      return await _pendingRequests[source]!;
    }

    // Inicia nova requisição e guarda no map
    final future = _loadLinesInternal(source);
    _pendingRequests[source] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      // Remove do map quando completar (sucesso ou erro)
      _pendingRequests.remove(source);
    }
  }

  static Future<List<String>> _loadLinesInternal(String source) async {
    if (source.startsWith('http')) {
      // Usa o mesmo método de cache que downloadAndCachePlaylist
      Future<File> cacheFile() async {
        return await _getCacheFile(source);
      }

      // Se cache local estiver válido, reutiliza
      try {
        final file = await cacheFile();
        if (await file.exists()) {
          final stat = await file.stat();
          if (DateTime.now().difference(stat.modified) < _cacheTtl) {
            print('💾 M3uService: Usando cache local (${stat.modified}) para $source');
            final cachedLines = await file.openRead().transform(utf8.decoder).transform(const LineSplitter()).toList();
            if (cachedLines.isNotEmpty) return cachedLines;
          }
        }
      } catch (_) {
        // se cache falhar, continua para download
      }

      // Fix: Se usar HTTPS com porta 80, troca para HTTP
      String fixedSource = source;
      if (source.startsWith('https://') && source.contains(':80')) {
        fixedSource = source.replaceFirst('https://', 'http://');
        print('⚠️ M3uService: Convertendo HTTPS:80 para HTTP:80 -> $fixedSource');
      }
      
      final client = http.Client();
      try {
        print('📡 M3uService: Baixando M3U de: $fixedSource');
        final req = await client.send(http.Request('GET', Uri.parse(fixedSource)));
        print('✅ M3uService: Status ${req.statusCode}, fazendo streaming...');
        final stream = req.stream.transform(utf8.decoder).transform(const LineSplitter());
        final lines = await stream.toList();

        // Salva cache local para próximas execuções
        try {
          final file = await cacheFile();
          await file.writeAsString(lines.join('\n'), flush: true);
          print('💾 M3uService: Cache salvo em ${file.path} (${lines.length} linhas)');
        } catch (e) {
          print('⚠️ M3uService: Falha ao salvar cache local: $e');
        }

        return lines;
      } catch (e) {
        print('❌ M3uService: Erro ao baixar: $e');
        // Se houver cache antigo, tenta devolver para não travar UI
        try {
          final file = await cacheFile();
          if (await file.exists()) {
            final cachedLines = await file.openRead().transform(utf8.decoder).transform(const LineSplitter()).toList();
            if (cachedLines.isNotEmpty) {
              print('💾 M3uService: Usando cache antigo após erro de download');
              return cachedLines;
            }
          }
        } catch (_) {}
        rethrow;
      } finally {
        client.close();
      }
    }

    // Trata file:// ou caminho absoluto
    final path = source.startsWith('file://') ? source.replaceFirst('file://', '') : source;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Arquivo não encontrado: $path');
    }
    final stream = file.openRead().transform(utf8.decoder).transform(const LineSplitter());
    return await stream.toList();
  }

  static List<ContentItem> _parseLines(List<String> lines, {int limit = 500}) {
    final items = <ContentItem>[];
    String? pendingExtInf;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXTINF')) {
        pendingExtInf = trimmed;
        continue;
      }

      // URL linha seguinte após EXTINF
      if (pendingExtInf != null && !trimmed.startsWith('#')) {
        final meta = _parseExtInf(pendingExtInf);
        final item = _buildContentItem(meta, trimmed);
        items.add(item);
        pendingExtInf = null;
        if (items.length >= limit) break;
      }
    }

    return items;
  }

  /// Buckets and categorization helpers
  static M3uBuckets makeBuckets(List<ContentItem> items) {
    final channels = <ContentItem>[];
    final movies = <ContentItem>[];
    final series = <ContentItem>[];
    final byGroup = <String, List<ContentItem>>{};

    for (final it in items) {
      // Quality flag - considera também o grupo para inferir qualidade
      it.quality = _inferQuality(it.title, it.group);

      switch (it.type) {
        case 'movie':
          movies.add(it);
          break;
        case 'series':
          series.add(it);
          break;
        default:
          channels.add(it);
      }
      byGroup.putIfAbsent(it.group, () => []).add(it);
    }
    return M3uBuckets(channels: channels, movies: movies, series: series, byGroup: byGroup);
  }

  static Map<String, String> _parseExtInf(String extInf) {
    // Exemplo: #EXTINF:-1 tvg-id="AMC" tvg-name="A&E FHD" tvg-logo="..." group-title="FILMES | SÉRIES",A&E FHD
    final attrs = <String, String>{};

    // Captura chave="valor"
    final regex = RegExp(r'(\w[\w\-]*)="([^"]*)"');
    for (final m in regex.allMatches(extInf)) {
      attrs[m.group(1)!] = m.group(2) ?? '';
    }

    // O título é o texto após a última vírgula
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex < extInf.length - 1) {
      attrs['title'] = extInf.substring(commaIndex + 1).trim();
    }

    return attrs;
  }

  static ContentItem _buildContentItem(Map<String, String> meta, String url) {
    final group = meta['group-title'] ?? 'Geral';
    final title = meta['title'] ?? meta['tvg-name'] ?? 'Sem título';
    final logo = meta['tvg-logo'] ?? '';
    final type = _inferType(group, title);
    final quality = _inferQuality(title, group);
    final audioType = _inferAudioType(title);

    return ContentItem(
      title: title,
      url: url,
      image: logo,
      group: group,
      type: type,
      isSeries: type == 'series',
      quality: quality,
      audioType: audioType,
    );
  }

  static String _inferType(String group, String title) {
    final g = group.toLowerCase();
    final t = title.toLowerCase();

    // === HEURÍSTICAS DE SEGMENTAÇÃO MELHORADAS ===
    // ORDEM DE PRIORIDADE (do mais específico ao mais genérico)

        // 🔴 REGRA -1 (PRIORIDADE MÁXIMA): "FILMES | SÉRIES" = CANAL (streaming contínuo)
    // Esta categoria específica contém canais de streaming, não filmes/séries individuais
    if (g.contains('filmes | séries') || g.contains('filmes | series') ||
        g.contains('filmes|séries') || g.contains('filmes|series')) {
      return 'channel';
    }

    // 🟢 REGRA 0 (NOVA): Categorias explícitas de FILMES 4K/UHD = FILME (antes de tudo!)/UHD = FILME (antes de tudo!)
    // Se o grupo contém "filmes 4k" ou "filmes uhd", é FILME independente do título
    if ((g.contains('filme') || g.contains('movie')) && 
        (g.contains('4k') || g.contains('uhd'))) {
      return 'movie';
    }

    // 🔵 REGRA 0.5: Categorias de SÉRIES 4K = SÉRIE
    if ((g.contains('série') || g.contains('serie') || g.contains('series')) && 
        (g.contains('4k') || g.contains('uhd'))) {
      return 'series';
    }

    // 🔴 REGRA 1: Qualidade no título = CANAL (mas só se grupo não for filme/série)
    // Padrão: "Nome FHD", "Nome HD", "Nome 4K", "Nome [UHD]"
    // NÃO aplica se o grupo já indica ser filme ou série
    final isFilmOrSeriesGroup = g.contains('filme') || g.contains('movie') || 
                                 g.contains('série') || g.contains('serie') || 
                                 g.contains('series') || g.contains('lançamento');
    if (!isFilmOrSeriesGroup && 
        RegExp(r'\b(fhd|4k|uhd)\b|hd²|fhd²| hd$| fhd$| 4k$| sd$|\[uhd\]|\[4k\]').hasMatch(t)) {
      return 'channel';
    }

    // 🔴 REGRA 2: Canais de streaming numerados (Amazon Prime 1, Netflix Live 1, etc)
    if (RegExp(r'(amazon prime|netflix|hbo|disney|paramount|globo play|star\+).*\d+$').hasMatch(t)) {
      return 'channel';
    }

    // 🔴 REGRA 3: Padrão de episódio explícito = SÉRIE
    if (RegExp(r's\d{2}e\d{2}|season\s*\d+|temporada\s*\d+|episódio\s*\d+').hasMatch(t)) {
      return 'series';
    }

    // 🔴 REGRA 4: UFC/Lutas com ano = considerados CANAIS/EVENTOS ao vivo
    if (g.contains('ufc') || g.contains('lutas') || g.contains('boxe')) {
      return 'channel';
    }

    // 🔴 REGRA 5: 24h / Streams contínuos = CANAL
    if (g.contains('24h') || g.contains('24 h') || g.contains('24hs')) {
      return 'channel';
    }

    // 🟢 REGRA 6: TV Aberta/Paga/Esportes = CANAL
    if (g.contains('tv aberta') || g.contains('tv paga') ||
        g.contains('globo') || g.contains('band') || g.contains('record') ||
        g.contains('sbt') || g.contains('cultura') || g.contains('futura') ||
        g.contains('sportv') || g.contains('espn') || g.contains('esporte') ||
        g.contains('futebol') || g.contains('dazn') || g.contains('premiere') ||
        g.contains('amc') || g.contains('axn') || g.contains('cinemax') ||
        g.contains('sony') || g.contains('space') || g.contains('lifetime') ||
        g.contains('universal') || g.contains('cartoon') || g.contains('discovery') ||
        g.contains('animal planet') || g.contains('natgeo') || g.contains('nat geo') ||
        g.contains('notícia') || g.contains('news') || g.contains('religioso') ||
        g.contains('gospel') || g.contains('canal') || g.contains('canais') ||
        g.contains('live') || g.contains('pay-per-view') || g.contains('pago') ||
        g.contains('adultos') || g.contains('xxx') || g.contains('variedades') ||
        g.contains('alternativo') || g.contains('pluto tv') ||
        g.contains('telecine') || g.contains('cine sky')) {
      return 'channel';
    }

    // 🟢 REGRA 7: Reality shows ao vivo = CANAL
    if (g.contains('a fazenda') || g.contains('power couple') || 
        g.contains('estrela da casa') || g.contains('big brother')) {
      return 'channel';
    }

    // 🟡 REGRA 8: Mega-categorias de séries (novelas, doramas, etc)
    if (g.contains('novela') || g.contains('series variadas') || 
        g.contains('dorama') || g.contains('tokusatsu')) {
      return 'series';
    }

    // 🟡 REGRA 9: Plataformas de streaming (Netflix, HBO, etc) = SÉRIE
    // Exceto se já foi identificado como canal numérico (regra 2)
    if (g.contains('netflix') || g.contains('globo play') || 
        g.contains('amazon prime video') || g.contains('amazon prime') ||
        g.contains('disney+') || g.contains('hbo max') || g.contains('hbo') ||
        g.contains('paramount+') || g.contains('paramount') ||
        g.contains('apple tv+') || g.contains('apple tv') ||
        g.contains('star+') || g.contains('star plus') ||
        g.contains('starz') || g.contains('discovery+')) {
      return 'series';
    }

    // 🟡 REGRA 10: Categorias explícitas de séries
    if (g.contains('série') || g.contains('serie') || g.contains('series') || 
        g.contains('anime') || g.contains('desenho') || g.contains('tokusatsu') ||
        g.contains('reelshort') || g.contains('cursos') ||
        g.contains('brasil paralelo') || g.contains('fitness') ||
        g.contains('shows nacionais') || g.contains('shows internacionais') ||
        g.contains('reality show')) {
      return 'series';
    }

    // 🔵 REGRA 11: Filmes explícitos
    if (g.contains('filme') || g.contains('movie') || g.contains('movies') ||
        g.contains('cinema') || g.contains('lançamento') || g.contains('réelshort')) {
      return 'movie';
    }

    // 🔵 REGRA 12: Gêneros de filme
    if (g.contains('ação') || g.contains('drama') || g.contains('comédia') ||
        g.contains('terror') || g.contains('suspense') || g.contains('romance') ||
        g.contains('ficção') || g.contains('fantasia') || g.contains('documentário') ||
        g.contains('guerra') || g.contains('faroeste') || g.contains('crime') ||
        g.contains('policial') || g.contains('nacional') || g.contains('musical') ||
        g.contains('nostalgia') || g.contains('clássicos') || g.contains('natal') ||
        g.contains('comic') || g.contains('marvel') || g.contains('herói') ||
        g.contains('aventura') || g.contains('animação')) {
      return 'movie';
    }

    // 🔵 REGRA 13: Top 10 / Destaques
    if (g.contains('top 10') || g.contains('sessão da tarde') ||
        g.contains('destaque') || g.contains('bestseller')) {
      return 'movie';
    }

    // === PADRÃO SEGURO FINAL ===
    // Se não foi identificado especificamente, assumir CANAL (padrão M3U)
    return 'channel';
  }

  static String _inferQuality(String title, [String group = '']) {
    final t = title.toLowerCase();
    final g = group.toLowerCase();
    
    // Primeiro verifica no título
    if (t.contains('[4k]') || t.contains('uhd') || t.contains('4k')) return 'uhd4k';
    if (t.contains('fhd')) return 'fhd';
    if (t.contains('hd')) return 'hd';
    
    // Se não encontrou no título, verifica no grupo/categoria
    if (g.contains('4k') || g.contains('uhd')) return 'uhd4k';
    if (g.contains('fhd')) return 'fhd';
    if (g.contains(' hd') || g.contains('_hd')) return 'hd';
    
    return 'sd';
  }

  static String _inferAudioType(String title) {
    final t = title.toLowerCase();
    if (t.contains('[leg]') || t.contains('(leg)') || t.contains('legendado')) return 'leg';
    if (t.contains('[dub]') || t.contains('(dub)') || t.contains('dublado')) return 'dub';
    if (t.contains('[multi]') || t.contains('(multi)')) return 'multi';
    return '';
  }
  static Map<String, String> extractSeriesInfo(String title) {
    final t = title.toLowerCase();
    final result = <String, String>{};
    
    // Padrão 1: S##E## ou S## E## ou s##e## (com ou sem espaço)
    var episodeRegex = RegExp(r's(\d{1,2})\s*e(\d{1,2})', caseSensitive: false);
    var match = episodeRegex.firstMatch(t);
    
    if (match == null) {
      // Padrão 2: ##x## ou #.# (ex: "01x05" ou "1.5")
      episodeRegex = RegExp(r'(\d{1,2})[x\.](\d{1,2})');
      match = episodeRegex.firstMatch(t);
    }
    
    if (match == null) {
      // Padrão 3: T##E## (ex: "T01E01" - temporada/episódio)
      episodeRegex = RegExp(r't(\d{1,2})\s*e(\d{1,2})', caseSensitive: false);
      match = episodeRegex.firstMatch(t);
    }
    
    if (match == null) {
      // Padrão 4: Temporada X Episódio Y (ex: "Temporada 2 Episódio 5")
      episodeRegex = RegExp(r'temporada\s+(\d{1,2})\s+episódio\s+(\d{1,2})', caseSensitive: false);
      match = episodeRegex.firstMatch(t);
    }
    
    if (match != null) {
      result['season'] = match.group(1) ?? '1';
      result['episode'] = match.group(2) ?? '0';
    } else {
      // Fallback: assumir temporada 1 se não conseguir extrair
      result['season'] = '1';
      result['episode'] = '0';
    }
    
    // Padrão: (Ano)
    final yearRegex = RegExp(r'\((\d{4})\)');
    final yearMatch = yearRegex.firstMatch(title);
    if (yearMatch != null) {
      result['year'] = yearMatch.group(1) ?? '';
    }
    
    return result;
  }

  /// Extrai um título base de série removendo padrões de temporada/episódio e ano.
  /// Ex: "The Office S05E12" -> "The Office"
  static String extractSeriesBaseTitle(String title) {
    var base = title;
    // Remove padrões S##E## ou S## E## (case-insensitive)
    base = base.replaceAll(RegExp(r'S\d{1,2}\s*E\d{1,2}', caseSensitive: false), '');
    // Remove (YYYY)
    base = base.replaceAll(RegExp(r'\(\d{4}\)'), '');
    // Remove espaçamentos e separadores redundantes
    base = base.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove traços/pipe no fim
    base = base.replaceAll(RegExp(r'[\-\|]+\s*$'), '').trim();
    return base.isEmpty ? title : base;
  }

  /// Garante cache de filmes em memória e usa compute para parse em isolate.
  static Future<void> _ensureMovieCache({required String source, int maxItems = 999999}) async {
    // Se não há playlist definida, mantém todos os caches vazios
    if (source.isEmpty) {
      _movieCache = [];
      _seriesCache = [];
      _channelCache = [];
      _movieCacheSource = null;
      _movieCacheMaxItems = 0;
      _movieCategories.clear();
      _movieCategoryCounts.clear();
      _movieCategoryThumb.clear();
      _seriesCategories.clear();
      _seriesCategoryCounts.clear();
      _seriesCategoryThumb.clear();
      _channelCategories.clear();
      _channelCategoryCounts.clear();
      _channelCategoryThumb.clear();
      return;
    }

    // Evita recomputar se já temos cache suficiente
    if (_movieCache != null &&
        _movieCacheSource == source &&
        _movieCache!.isNotEmpty &&
        _movieCacheMaxItems >= maxItems) {
      return;
    }

    final key = '$source::$maxItems';
    if (_pendingCacheEnsures.containsKey(key)) {
      await _pendingCacheEnsures[key];
      return;
    }

    // Sem limite artificial - carrega tudo
    final safeLimit = maxItems;

    final future = () async {
      final lines = await _loadLines(source);
      final parsedMaps = await compute(_parseLinesIsolate, {
        'lines': lines,
        'limit': safeLimit,
      });

      final movies = <ContentItem>[];
      final series = <ContentItem>[];
      final channels = <ContentItem>[];
      final counts = <String, int>{};
      final cats = <String>{};
      final thumbs = <String, String>{};
      final sCounts = <String, int>{};
      final sCats = <String>{};
      final sThumbs = <String, String>{};
      final cCounts = <String, int>{};
      final cCats = <String>{};
      final cThumbs = <String, String>{};

      for (final m in parsedMaps) {
        final item = ContentItem(
          title: m['title'] ?? 'Sem título',
          url: m['url'] ?? '',
          image: m['image'] ?? '',
          group: m['group'] ?? 'Geral',
          type: m['type'] ?? 'movie',
          isSeries: m['type'] == 'series',
          quality: m['quality'] ?? 'sd',
          audioType: m['audioType'] ?? '',
        );
        if (item.type == 'movie') {
          movies.add(item);
          cats.add(item.group);
          counts[item.group] = (counts[item.group] ?? 0) + 1;
          if (thumbs[item.group] == null || thumbs[item.group]!.isEmpty) {
            if (item.image.isNotEmpty) {
              thumbs[item.group] = item.image;
            }
          }
        } else if (item.type == 'series') {
          series.add(item);
          sCats.add(item.group);
          sCounts[item.group] = (sCounts[item.group] ?? 0) + 1;
          if (sThumbs[item.group] == null || sThumbs[item.group]!.isEmpty) {
            if (item.image.isNotEmpty) sThumbs[item.group] = item.image;
          }
        } else {
          channels.add(item);
          cCats.add(item.group);
          cCounts[item.group] = (cCounts[item.group] ?? 0) + 1;
          if (cThumbs[item.group] == null || cThumbs[item.group]!.isEmpty) {
            if (item.image.isNotEmpty) cThumbs[item.group] = item.image;
          }
        }
      }

      _movieCache = movies;
      _seriesCache = series;
      _channelCache = channels;
      _movieCacheSource = source;
      _movieCacheMaxItems = safeLimit;
      _movieCategoryCounts = counts;
      _movieCategories = cats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _movieCategoryThumb = thumbs;
      _seriesCategoryCounts = sCounts;
      _seriesCategories = sCats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _seriesCategoryThumb = sThumbs;
      _channelCategoryCounts = cCounts;
      _channelCategories = cCats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _channelCategoryThumb = cThumbs;
      
      print('📊 M3uService Cache: ${movies.length} filmes, ${series.length} séries, ${channels.length} canais');
      print('📊 Categorias: ${cats.length} filmes, ${sCats.length} séries, ${cCats.length} canais');
      if (sCats.isNotEmpty) {
        print('📁 Categorias de séries detectadas: ${_seriesCategories.join(", ")}');
        for (final cat in _seriesCategories.take(5)) {
          print('   - $cat: ${sCounts[cat]} séries');
        }
        if (_seriesCategories.length > 5) {
          print('   ... e mais ${_seriesCategories.length - 5} categorias');
        }
      }
      if (cats.isNotEmpty) {
        print('📁 Categorias de filmes (primeiras 5): ${_movieCategories.take(5).join(", ")}');
      }
      if (cCats.isNotEmpty) {
        print('📁 Categorias de canais (primeiras 5): ${_channelCategories.take(5).join(", ")}');
      }
    }();

    _pendingCacheEnsures[key] = future;
    try {
      await future;
    } finally {
      _pendingCacheEnsures.remove(key);
    }
  }

  /// Retorna itens filtrados por categoria (group) usando o cache paginado
  /// para evitar reparse e travar a main isolate.
  static Future<List<ContentItem>> fetchCategoryItemsFromEnv({
    required String category,
    String typeFilter = 'movie',
    int maxItems = 999999,
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      throw Exception('M3U_PLAYLIST_URL não definido no .env');
    }

    await _ensureMovieCache(source: source, maxItems: maxItems);

    final normalized = category.trim().toLowerCase();
    final base = (typeFilter == 'series')
      ? (_seriesCache ?? const <ContentItem>[])
      : (typeFilter == 'channel')
        ? (_channelCache ?? const <ContentItem>[])
        : (_movieCache ?? const <ContentItem>[]);
    return base
      .where((e) => e.group.trim().toLowerCase() == normalized)
      .toList();
  }

  /// Retorna um mapa categoria -> thumb (primeira imagem encontrada) e contagens.
  static Future<M3uCategoryMeta> fetchCategoryMetaFromEnv({
    String typeFilter = 'movie',
    int maxItems = 999999,
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      throw Exception('M3U_PLAYLIST_URL não definido no .env');
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    if (typeFilter == 'series') {
      return M3uCategoryMeta(categories: _seriesCategories, counts: _seriesCategoryCounts, thumbs: _seriesCategoryThumb);
    }
    if (typeFilter == 'channel') {
      return M3uCategoryMeta(categories: _channelCategories, counts: _channelCategoryCounts, thumbs: _channelCategoryThumb);
    }
    return M3uCategoryMeta(categories: _movieCategories, counts: _movieCategoryCounts, thumbs: _movieCategoryThumb);
  }

  /// Retorna uma lista agregada por série (título base) para a categoria informada.
  /// Útil para navegar primeiro por séries, depois abrir temporadas/episódios na tela de detalhes.
  static Future<List<ContentItem>> fetchSeriesAggregatedForCategory({
    required String category,
    int maxItems = 999999,
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      throw Exception('M3U_PLAYLIST_URL não definido no .env');
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final normalized = category.trim().toLowerCase();
    final list = (_seriesCache ?? const <ContentItem>[])
        .where((e) => e.group.trim().toLowerCase() == normalized)
        .toList();
    final map = <String, ContentItem>{};
    for (final it in list) {
      final baseTitle = extractSeriesBaseTitle(it.title);
      if (!map.containsKey(baseTitle)) {
        // Usa a primeira imagem disponível para a capa da série
        final cover = it.image.isNotEmpty
            ? it.image
            : list.firstWhere(
                (x) => extractSeriesBaseTitle(x.title) == baseTitle && x.image.isNotEmpty,
                orElse: () => it,
              ).image;
        map[baseTitle] = ContentItem(
          title: baseTitle,
          url: it.url, // um URL de exemplo (episódio) será substituído na tela de detalhes
          image: cover,
          group: it.group,
          type: 'series',
          isSeries: true,
          quality: it.quality,
          audioType: it.audioType,
        );
      }
    }
    final aggregated = map.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return aggregated;
  }

  /// Retorna os "últimos filmes" com base na ordem da playlist (assumindo que a
  /// fonte lista adições recentes no topo). Limita por [count].
  static Future<List<ContentItem>> getLatestMovies({int count = 20, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) throw Exception('M3U_PLAYLIST_URL não definido no .env');
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final list = _movieCache ?? const <ContentItem>[];
    return list.take(count).toList();
  }

  /// Seleção determinística diária de destaques com viés para melhor qualidade e com imagem.
  /// Usa um pool inicial dos itens mais recentes e faz uma seleção baseada em seed.
  static Future<List<ContentItem>> getDailyFeaturedMovies({int count = 6, int pool = 80, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) throw Exception('M3U_PLAYLIST_URL não definido no .env');
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final total = _movieCache?.length ?? 0;
    if (total == 0) return const [];

    final take = pool.clamp(1, total);
    final candidates = _movieCache!
        .take(take)
        .where((e) => e.image.isNotEmpty)
        .toList();

    int qualityScore(String q) {
      switch (q) {
        case 'uhd4k':
          return 4;
        case 'fhd':
          return 3;
        case 'hd':
          return 2;
        default:
          return 1;
      }
    }

    candidates.sort((a, b) => qualityScore(b.quality).compareTo(qualityScore(a.quality)));

    // Seed diário baseado em AAAA-MM-DD
    final now = DateTime.now();
    final key = '${now.year}-${now.month}-${now.day}';
    final seed = key.hashCode & 0x7fffffff;
    final rng = Random(seed);

    // Seleção determinística: rotate por offset e pegar [count]
    if (candidates.isEmpty) return const [];
    final offset = rng.nextInt(candidates.length);
    final rotated = [...candidates.sublist(offset), ...candidates.sublist(0, offset)];
    return rotated.take(count).toList();
  }

  // Generic helpers by type
  static Future<List<ContentItem>> getLatestByType(String type, {int count = 20, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) throw Exception('M3U_PLAYLIST_URL não definido no .env');
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final list = type == 'series'
        ? (_seriesCache ?? const <ContentItem>[])
        : type == 'channel'
            ? (_channelCache ?? const <ContentItem>[])
            : (_movieCache ?? const <ContentItem>[]);
    return list.take(count).toList();
  }

  static Future<List<ContentItem>> getDailyFeaturedByType(String type, {int count = 6, int pool = 80, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) throw Exception('M3U_PLAYLIST_URL não definido no .env');
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final base = type == 'series'
        ? (_seriesCache ?? const <ContentItem>[])
        : type == 'channel'
            ? (_channelCache ?? const <ContentItem>[])
            : (_movieCache ?? const <ContentItem>[]);
    final total = base.length;
    print('📺 getDailyFeaturedByType($type): base tem $total items');
    if (total == 0) return const [];
    final take = pool.clamp(1, total);
    // Para canais, não exigir imagem pois muitos não têm
    final candidates = type == 'channel'
        ? base.take(take).toList()
        : base.take(take).where((e) => e.image.isNotEmpty).toList();
    print('📺 getDailyFeaturedByType($type): ${candidates.length} candidates após filtro');
    int qualityScore(String q) {
      switch (q) {
        case 'uhd4k':
          return 4;
        case 'fhd':
          return 3;
        case 'hd':
          return 2;
        default:
          return 1;
      }
    }
    candidates.sort((a, b) => qualityScore(b.quality).compareTo(qualityScore(a.quality)));
    final now = DateTime.now();
    final key = '${type}-${now.year}-${now.month}-${now.day}';
    final seed = key.hashCode & 0x7fffffff;
    final rng = Random(seed);
    if (candidates.isEmpty) return const [];
    final offset = rng.nextInt(candidates.length);
    final rotated = [...candidates.sublist(offset), ...candidates.sublist(0, offset)];
    return rotated.take(count).toList();
  }

  /// Curated featured: optional external JSON controlled via FEATURED_JSON_URL.
  static Future<List<ContentItem>> getCuratedFeaturedPrefer(String type, {int count = 6, int pool = 120, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) throw Exception('M3U_PLAYLIST_URL não definido no .env');
    await _ensureMovieCache(source: source, maxItems: maxItems);

    final curatedUrl = Config.curatedFeaturedUrl;
    if (curatedUrl != null && curatedUrl.isNotEmpty) {
      try {
        if (_curatedFeaturedCache == null || _curatedFeaturedFetchedAt == null || DateTime.now().difference(_curatedFeaturedFetchedAt!).inHours >= 1) {
          final res = await http.get(Uri.parse(curatedUrl));
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final map = <String, List<String>>{};
            for (final t in ['movie', 'series', 'channel']) {
              final v = data[t] ?? data['${t}s'];
              if (v is List) {
                final urls = <String>[];
                for (final e in v) {
                  if (e is String) urls.add(e);
                  if (e is Map && e['url'] is String) urls.add(e['url']);
                }
                map[t] = urls;
              }
            }
            _curatedFeaturedCache = map;
            _curatedFeaturedFetchedAt = DateTime.now();
          }
        }

        final urls = _curatedFeaturedCache?[type] ?? const <String>[];
        if (urls.isNotEmpty) {
          final base = type == 'series'
              ? (_seriesCache ?? const <ContentItem>[])
              : type == 'channel'
                  ? (_channelCache ?? const <ContentItem>[])
                  : (_movieCache ?? const <ContentItem>[]);
          final byUrl = {for (final it in base) it.url: it};
          final curatedItems = <ContentItem>[];
          for (final u in urls) {
            final it = byUrl[u];
            if (it != null) curatedItems.add(it);
            if (curatedItems.length >= count) break;
          }
          if (curatedItems.isNotEmpty) return curatedItems;
        }
      } catch (e) {
        // ignore curated errors, fallback below
      }
    }

    // Fallback to deterministic daily
    return getDailyFeaturedByType(type, count: count, pool: pool, maxItems: maxItems);
  }

  /// Busca conteúdo por termo em todas as categorias (filmes, séries, canais)
  static Future<List<ContentItem>> searchAllContent(String query, {int maxResults = 200, int maxItems = 999999}) async {
    if (query.isEmpty || query.length < 2) return [];
    
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) return [];
    
    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    final q = query.toLowerCase().trim();
    final results = <ContentItem>[];
    
    // Buscar em filmes
    for (final item in (_movieCache ?? [])) {
      if (results.length >= maxResults) break;
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        results.add(item);
      }
    }
    
    // Buscar em séries (agregar por título base para não duplicar)
    final seenSeries = <String>{};
    for (final item in (_seriesCache ?? [])) {
      if (results.length >= maxResults) break;
      final baseTitle = extractSeriesBaseTitle(item.title).toLowerCase();
      if (seenSeries.contains(baseTitle)) continue;
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        seenSeries.add(baseTitle);
        results.add(item);
      }
    }
    
    // Buscar em canais
    for (final item in (_channelCache ?? [])) {
      if (results.length >= maxResults) break;
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        results.add(item);
      }
    }
    
    return results;
  }

  /// Busca detalhes de uma série agrupando episódios por temporada
  static Future<SeriesDetails?> fetchSeriesDetailsFromM3u(String seriesTitle, String category, {String? audioType, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) return null;

    await _ensureMovieCache(source: source, maxItems: maxItems);

    // Normaliza e usa o título base para evitar misturar séries diferentes
    final targetBase = extractSeriesBaseTitle(seriesTitle).toLowerCase();
    final normalizedCat = category.trim().toLowerCase();

    var allEpisodes = (_seriesCache ?? [])
        .where((item) =>
            item.group.trim().toLowerCase() == normalizedCat &&
            extractSeriesBaseTitle(item.title).toLowerCase() == targetBase)
        .toList();

    if (allEpisodes.isEmpty) return null;

    // Filtrar por audioType se especificado
    if (audioType != null && audioType.isNotEmpty) {
      allEpisodes = allEpisodes.where((ep) => ep.audioType.toLowerCase() == audioType.toLowerCase()).toList();
    }

    if (allEpisodes.isEmpty) return null;

    // Agrupar por temporada com rótulos legíveis
    final Map<String, List<ContentItem>> seasonMap = {};
    for (final ep in allEpisodes) {
      final info = extractSeriesInfo(ep.title);
      final seasonNum = info['season'] ?? '1';
      final seasonLabel = 'Temporada ${seasonNum.padLeft(2, '0')}';
      seasonMap.putIfAbsent(seasonLabel, () => <ContentItem>[]).add(ep);
    }

    // Ordenar episódios dentro de cada temporada (por número, senão por título)
    seasonMap.forEach((label, episodes) {
      episodes.sort((a, b) {
        final ia = extractSeriesInfo(a.title);
        final ib = extractSeriesInfo(b.title);
        final ea = int.tryParse(ia['episode'] ?? '0') ?? 0;
        final eb = int.tryParse(ib['episode'] ?? '0') ?? 0;
        if (ea != eb) return ea.compareTo(eb);
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    });

    return SeriesDetails(seasons: seasonMap, selectedAudioType: audioType);
  }

  /// Retorna uma lista com os audioTypes disponíveis para uma série
  static Future<List<String>> getAvailableAudioTypesForSeries(String seriesTitle, String category, {int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) return [];

    await _ensureMovieCache(source: source, maxItems: maxItems);

    final targetBase = extractSeriesBaseTitle(seriesTitle).toLowerCase();
    final normalizedCat = category.trim().toLowerCase();

    final allEpisodes = (_seriesCache ?? [])
        .where((item) =>
            item.group.trim().toLowerCase() == normalizedCat &&
            extractSeriesBaseTitle(item.title).toLowerCase() == targetBase)
        .toList();

    // Coletar tipos de áudio únicos
    final audioTypes = <String>{};
    for (final ep in allEpisodes) {
      if (ep.audioType.isNotEmpty) {
        audioTypes.add(ep.audioType.toLowerCase());
      }
    }

    return audioTypes.toList();
  }
}

class M3uCategoryMeta {
  final List<String> categories;
  final Map<String, int> counts;
  final Map<String, String> thumbs;

  const M3uCategoryMeta({required this.categories, required this.counts, required this.thumbs});
}

class M3uPagedResult {
  final List<ContentItem> items;
  final int total;
  final List<String> categories;
  final Map<String, int> categoryCounts;

  const M3uPagedResult({
    required this.items,
    required this.total,
    required this.categories,
    required this.categoryCounts,
  });
}

/// Função top-level para usar com `compute` e evitar travar a main isolate.
List<Map<String, String>> _parseLinesIsolate(Map<String, dynamic> args) {
  final lines = (args['lines'] as List<dynamic>).cast<String>();
  final limit = args['limit'] as int? ?? 2000;

  final results = <Map<String, String>>[];
  String? pendingExtInf;
  
  int movieCount = 0, seriesCount = 0, channelCount = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('#EXTINF')) {
      pendingExtInf = trimmed;
      continue;
    }

    if (pendingExtInf != null && !trimmed.startsWith('#')) {
      final meta = M3uService._parseExtInf(pendingExtInf);
      final groupTitle = meta['group-title'] ?? 'Geral';
      final title = meta['title'] ?? meta['tvg-name'] ?? '';
      final type = M3uService._inferType(groupTitle, title);
      final quality = M3uService._inferQuality(title, groupTitle);
      final audioType = M3uService._inferAudioType(title);
      
      // Debug primeiros itens
      if (results.length < 5) {
        print('🔍 Parse[${ results.length}] group="${meta['group-title']}" title="${meta['title']}" → type=$type');
      }
      
      if (type == 'movie') movieCount++;
      else if (type == 'series') seriesCount++;
      else channelCount++;
      
      results.add({
        'title': meta['title'] ?? meta['tvg-name'] ?? 'Sem título',
        'url': trimmed,
        'image': meta['tvg-logo'] ?? '',
        'group': meta['group-title'] ?? 'Geral',
        'type': type,
        'quality': quality,
        'audioType': audioType,
      });
      pendingExtInf = null;
      if (results.length >= limit) break;
    }
  }
  
  print('📊 Parse total: $movieCount filmes, $seriesCount séries, $channelCount canais (de ${results.length} itens)');

  return results;
}

class M3uBuckets {
  final List<ContentItem> channels;
  final List<ContentItem> movies;
  final List<ContentItem> series;
  final Map<String, List<ContentItem>> byGroup;

  M3uBuckets({required this.channels, required this.movies, required this.series, required this.byGroup});
}
