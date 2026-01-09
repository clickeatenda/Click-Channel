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
import '../utils/content_enricher.dart';

/// Serviço para ler e normalizar playlists M3U diretamente no app (opção B).
/// Suporta tanto URL (HTTP/HTTPS) quanto caminho de arquivo local (file:// ou caminho absoluto).
class M3uService {
  // CRÍTICO: Inicializa como null, não como lista vazia
  // Isso garante que sem playlist configurada, o cache não será usado
  static List<ContentItem>? _movieCache;
  static List<ContentItem>? _seriesCache;
  static List<ContentItem>? _channelCache;
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
  // Cache permanente - não expira automaticamente
  // O cache só é atualizado quando o usuário solicita explicitamente
  static const Duration _cacheTtl = Duration(days: 365); // 1 ano (efetivamente permanente)
  
  // Flag para indicar que preload foi feito
  static bool _preloadDone = false;
  static String? _preloadSource;
  
  // Proteção contra requisições duplicadas simultâneas
  static final Map<String, Future<List<String>>> _pendingRequests = {};
  // Completers para sinalizar quando o preload de uma source específica termina
  static final Map<String, Completer<void>> _preloadCompleters = {};

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
  /// IMPORTANTE: Sempre limpa TODOS os caches para evitar conflitos com listas antigas
  /// Se newSource for fornecido, mantém apenas o cache dessa URL (se existir)
  static Future<void> clearAllCache(String? newSource) async {
    print('🧹 M3uService: Limpando TODOS os caches (memória e disco)...');
    if (newSource != null && newSource.isNotEmpty) {
      print('   Mantendo apenas cache para: ${newSource.substring(0, newSource.length > 50 ? 50 : newSource.length)}...');
    }
    
    // Limpa memória
    clearMemoryCache();
    
    // Limpa TODOS os arquivos de cache M3U no disco
    // EXCETO se newSource for fornecido e o cache corresponder a essa URL
    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir.listSync();
      int deletedCount = 0;
      File? keepFile;
      
      // Se newSource foi fornecido, identifica qual arquivo manter
      if (newSource != null && newSource.isNotEmpty) {
        try {
          keepFile = await _getCacheFile(newSource);
        } catch (e) {
          print('⚠️ M3uService: Erro ao identificar cache para manter: $e');
        }
      }
      
      for (final file in files) {
        if (file is File && (file.path.contains('m3u_cache_') || file.path.contains('m3u_meta_'))) {
          // Se este é o arquivo que queremos manter, pula
          if (keepFile != null && file.path == keepFile.path) {
            print('💾 M3uService: Mantendo cache válido: ${file.path}');
            continue;
          }
          
          // Deleta todos os outros caches
          try {
            await file.delete();
            deletedCount++;
            print('🗑️ M3uService: Cache deletado: ${file.path}');
          } catch (e) {
            print('⚠️ M3uService: Erro ao deletar ${file.path}: $e');
          }
        }
      }
      print('✅ M3uService: ${deletedCount} arquivo(s) de cache deletado(s)');
    } catch (e) {
      print('❌ M3uService: Erro ao limpar caches de disco: $e');
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

  static Future<File> _getMetaCacheFile(String source) async {
    final dir = await getApplicationSupportDirectory();
    final hash = source.hashCode;
    return File('${dir.path}/m3u_meta_$hash.json');
  }

  /// Salva os nomes das categorias e contagens em um arquivo JSON leve.
  /// Isso permite que o app exiba as categorias instantaneamente sem abrir o M3U de 100MB+.
  static Future<void> _saveMetaCache(String source) async {
    try {
      final file = await _getMetaCacheFile(source);
      final data = {
        'movie_categories': _movieCategories,
        'movie_counts': _movieCategoryCounts,
        'movie_thumbs': _movieCategoryThumb,
        'series_categories': _seriesCategories,
        'series_counts': _seriesCategoryCounts,
        'series_thumbs': _seriesCategoryThumb,
        'channel_categories': _channelCategories,
        'channel_counts': _channelCategoryCounts,
        'channel_thumbs': _channelCategoryThumb,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
      print('💾 M3uService: Meta-dados de categorias salvos em disco');
    } catch (e) {
      print('⚠️ M3uService: Erro ao salvar meta-cache: $e');
    }
  }

  /// Carrega os nomes das categorias do disco (Rápido).
  static Future<bool> loadMetaCache(String source) async {
    try {
      if (source.isEmpty) return false;
      final file = await _getMetaCacheFile(source);
      if (!await file.exists()) return false;
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      _movieCategories = List<String>.from(data['movie_categories'] ?? []);
      _movieCategoryCounts = Map<String, int>.from(data['movie_counts'] ?? {});
      _movieCategoryThumb = Map<String, String>.from(data['movie_thumbs'] ?? {});
      
      _seriesCategories = List<String>.from(data['series_categories'] ?? []);
      _seriesCategoryCounts = Map<String, int>.from(data['series_counts'] ?? {});
      _seriesCategoryThumb = Map<String, String>.from(data['series_thumbs'] ?? {});
      
      _channelCategories = List<String>.from(data['channel_categories'] ?? []);
      _channelCategoryCounts = Map<String, int>.from(data['channel_counts'] ?? {});
      _channelCategoryThumb = Map<String, String>.from(data['channel_thumbs'] ?? {});
      
      _movieCacheSource = source;
      _movieCacheMaxItems = 999999; // Marca como tendo categorias completas
      print('✅ M3uService: Meta-dados carregados do disco (${_movieCategories.length} filmes, ${_seriesCategories.length} séries)');
      return true;
    } catch (e) {
      print('⚠️ M3uService: Erro ao carregar meta-cache: $e');
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

  /// Deleta o install marker (usado para forçar limpeza completa)
  static Future<void> deleteInstallMarker() async {
    try {
      final file = await _getInstallMarkerFile();
      if (await file.exists()) {
        await file.delete();
        print('🗑️ M3uService: Install marker deletado');
      }
    } catch (e) {
      print('⚠️ M3uService: Erro ao deletar install marker: $e');
    }
  }

  // ============= MÉTODOS PARA SETUP SCREEN =============
  
  /// Verifica se existe cache local válido para a URL
  /// IMPORTANTE: Cache é permanente - sempre válido se existir e não estiver corrompido
  static Future<bool> hasCachedPlaylist(String source) async {
    try {
      final file = await _getCacheFile(source);
      print('🔍 M3uService: Verificando cache em: ${file.path}');
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        print('🔍 M3uService: Cache existe, idade: ${age.inDays} dias, tamanho: ${(stat.size / 1024).toStringAsFixed(1)} KB');
        
        // Verifica se arquivo não está vazio
        if (stat.size == 0) {
          print('⚠️ M3uService: Cache existe mas está vazio - inválido');
          return false;
        }
        
        // Valida integridade básica: verifica se tem pelo menos uma linha M3U válida
        try {
          final lines = await file.openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .take(20) // Lê apenas primeiras 20 linhas para validação rápida
              .toList();
          
          // Deve ter pelo menos #EXTM3U ou #EXTINF para ser válido
          final hasValidM3uHeader = lines.any((line) => 
              line.trim().startsWith('#EXTM3U') || 
              line.trim().startsWith('#EXTINF'));
          
          if (!hasValidM3uHeader) {
            print('⚠️ M3uService: Cache existe mas não contém formato M3U válido');
            return false;
          }
          
          print('✅ M3uService: Cache válido (permanente) - formato M3U confirmado!');
          return true;
        } catch (e) {
          print('⚠️ M3uService: Erro ao validar formato do cache: $e');
          // Se não conseguir validar, assume válido (melhor que perder dados)
          return true;
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
  /// IMPORTANTE: Usa hashCode da URL para identificar cache único por URL
  static Future<File> _getCacheFile(String source) async {
    final dir = await getApplicationSupportDirectory();
    // Normaliza a URL (remove trailing slash, etc) para garantir mesmo hashCode
    final normalizedSource = source.trim().replaceAll(RegExp(r'/+$'), '');
    final safe = normalizedSource.hashCode;
    final filePath = '${dir.path}/m3u_cache_$safe.m3u';
    print('💾 M3uService: Cache file para "${normalizedSource.substring(0, normalizedSource.length > 50 ? 50 : normalizedSource.length)}...": $filePath');
    return File(filePath);
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
    final sourceKey = source.trim();
    // Registra completer para sinalizar conclusão do preload IMEDIATAMENTE e de forma síncrona
    if (!_preloadCompleters.containsKey(sourceKey)) {
      _preloadCompleters[sourceKey] = Completer<void>();
    }
    
    // Tenta carregar meta-cache do disco primeiro (MUITO RÁPIDO)
    // Isso resolve o problema das categorias não aparecerem na Home
    await loadMetaCache(source);

    // CRÍTICO: Valida que a source corresponde à URL salva em Prefs
    final savedUrl = Config.playlistRuntime;
    final normalizedSource = source.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedSaved = savedUrl?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
    
    if (normalizedSaved.isEmpty) {
      print('⚠️ M3uService: preloadCategories - Sem URL salva em Prefs! Limpando cache e abortando.');
      clearMemoryCache();
      return;
    }
    
    if (normalizedSource != normalizedSaved) {
      print('⚠️ M3uService: preloadCategories - Source não corresponde à URL salva!');
      print('   Source: ${normalizedSource.substring(0, normalizedSource.length > 50 ? 50 : normalizedSource.length)}...');
      print('   Salva: ${normalizedSaved.substring(0, normalizedSaved.length > 50 ? 50 : normalizedSaved.length)}...');
      clearMemoryCache();
      return;
    }
    
    // Se já fez preload para essa source E a source corresponde, não refaz
    if (_preloadDone && _preloadSource == source) {
      print('♻️ M3uService: Preload já feito para essa source');
      return;
    }
    
    // CRÍTICO: Limpa apenas o cache de ITENS (pesado) antes de fazer preload
    // Não limpa as listas de categorias (_movieCategories), pois elas foram 
    // povoadas pelo loadMetaCache(source) logo acima e são usadas pela Home.
    _movieCache = null;
    _seriesCache = null;
    _channelCache = null;
    print('🧹 M3uService: Limpando caches de itens pesados antes de preload...');
    
    try {
    final file = await _getCacheFile(source);
    if (!await file.exists()) {
      print('⚠️ M3uService: Cache não encontrado para preload');
      return;
    }

    print('📦 M3uService: Iniciando preload via isolate (Arquivo: ${file.path})...');
    
    // Parse em isolate passando o PATH do arquivo - MUITO mais eficiente em memória
    // Evita copiar a lista de strings entre isolados
    final parsedMaps = await compute(_parseFileIsolate, {
      'path': file.path, 
      'limit': 999999
    });
    
    print('📦 M3uService: Isolate retornou ${parsedMaps.length} itens');
    
    final items = parsedMaps.map((m) => ContentItem(
      title: m['title'] ?? '',
      url: m['url'] ?? '',
      image: m['image'] ?? '',
      group: m['group'] ?? 'Geral',
      type: m['type'] ?? 'movie',
      quality: m['quality'] ?? 'sd',
      audioType: m['audioType'] ?? '',
      year: m['year'] ?? '',
    )).toList();
    
    // Separa por tipo
    final movieItems = items.where((i) => i.type == 'movie').toList();
    final seriesItems = items.where((i) => i.type == 'series').toList();
    final channelItems = items.where((i) => i.type != 'movie' && i.type != 'series').toList();

    // Cacheia os items
    _movieCache = movieItems;
    _seriesCache = seriesItems;
    _channelCache = channelItems;
    _movieCacheSource = source;
    _movieCacheMaxItems = 999999;

    // Extrai categorias
    _extractCategories(movieItems, _movieCategories, _movieCategoryCounts, _movieCategoryThumb);
    _extractCategories(seriesItems, _seriesCategories, _seriesCategoryCounts, _seriesCategoryThumb);
    _extractCategories(channelItems, _channelCategories, _channelCategoryCounts, _channelCategoryThumb);

    // Marca preload como feito
    _preloadDone = true;
    _preloadSource = source;

    // Salva meta-dados em disco para o próximo boot rápido
    await _saveMetaCache(source);

    // Completa o completer associado
    try {
      final c = _preloadCompleters[source.trim()];
      if (c != null && !c.isCompleted) c.complete();
    } catch (_) {}
      print('✅ M3uService: Preload concluído - ${movieItems.length} filmes, ${seriesItems.length} séries, ${channelItems.length} canais');
      print('✅ M3uService: ${_movieCategories.length} cat filmes, ${_seriesCategories.length} cat séries');
    } catch (e) {
      print('⚠️ M3uService: Erro no preload: $e');
      try {
        final c = _preloadCompleters[source.trim()];
        if (c != null && !c.isCompleted) c.completeError(e);
      } catch (_) {}
    }
  }

  /// Aguarda até que o preload para uma source específica seja concluído
  /// Retorna true se o preload estiver completo ou for concluído dentro do timeout
  static Future<bool> waitUntilPreloaded(String source, {Duration timeout = const Duration(seconds: 4)}) async {
    if (source.trim().isEmpty) return false;
    if (isPreloaded(source)) return true;
    final key = source.trim();
    try {
      final completer = _preloadCompleters.putIfAbsent(key, () => Completer<void>());
      await completer.future.timeout(timeout);
      return isPreloaded(source);
    } catch (_) {
      return isPreloaded(source);
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
      print('⚠️ M3uService: fetchFromEnv - Sem URL configurada, retornando lista vazia');
      return [];
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
      print('⚠️ M3uService: fetchPagedFromEnv - Sem URL configurada, retornando vazio');
      return const M3uPagedResult(items: [], total: 0, categories: [], categoryCounts: {});
    }

    if (typeFilter != 'movie') {
      // Por enquanto, apenas filmes são suportados no cache paginado
      throw Exception('fetchPagedFromEnv suporta apenas filmes no momento');
    }

    // CRÍTICO: Verifica se cache já está carregado antes de forçar reload
    // Se cache já existe e corresponde à source, usa diretamente (muito mais rápido)
    final cacheExists = _movieCache != null && 
                       _movieCacheSource == source && 
                       _movieCache!.isNotEmpty &&
                       _movieCacheMaxItems >= maxItems;
    
    if (!cacheExists) {
      print('📦 M3uService: Cache não existe ou não corresponde - carregando...');
      await _ensureMovieCache(source: source, maxItems: maxItems);
    } else {
      print('⚡ M3uService: Usando cache existente (${_movieCache!.length} itens) - carregamento instantâneo!');
    }
    
    // CRÍTICO: Se o cache de itens ainda é null (preload em curso), retorna lista vazia
    // mas inclui as categorias já conhecidas (via meta-cache) para que a UI monte a estrutura.
    if (_movieCache == null) {
      print('ℹ️ M3uService: fetchPagedFromEnv - Cache de itens ainda não pronto. Retornando categorias conhecidas.');
      return M3uPagedResult(
        items: const [],
        total: 0,
        categories: _movieCategories,
        categoryCounts: _movieCategoryCounts,
      );
    }

    final total = _movieCache!.length;
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
      // CRÍTICO: Verifica se a URL atual corresponde à URL salva em Prefs
      // Se não corresponder, NÃO usa cache antigo (pode ser de lista diferente)
      final savedUrl = Config.playlistRuntime;
      final normalizedSource = source.trim().replaceAll(RegExp(r'/+$'), '');
      final normalizedSaved = savedUrl?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
      
      // Usa o mesmo método de cache que downloadAndCachePlaylist
      Future<File> cacheFile() async {
        return await _getCacheFile(source);
      }

      // CRÍTICO: Só usa cache se:
      // 1. Cache existe
      // 2. URL salva em Prefs existe E corresponde exatamente à URL atual
      // NUNCA usa cache se não há URL salva (pode ser cache de lista antiga)
      try {
        final file = await cacheFile();
        if (await file.exists()) {
          // CRÍTICO: Se não há URL salva, NÃO usa cache (pode ser de lista antiga)
          if (normalizedSaved.isEmpty) {
            print('⚠️ M3uService: Cache existe mas não há URL salva em Prefs! Deletando cache antigo...');
            try {
              await file.delete();
              print('🗑️ M3uService: Cache antigo deletado (sem URL salva)');
            } catch (e) {
              print('⚠️ M3uService: Erro ao deletar cache antigo: $e');
            }
            // Continua para baixar nova playlist
          } else if (normalizedSource == normalizedSaved) {
            // URL corresponde exatamente - pode usar cache
            final stat = await file.stat();
            print('💾 M3uService: Cache local encontrado (${stat.modified}) para URL correspondente');
            print('   URL: ${normalizedSource.substring(0, normalizedSource.length > 50 ? 50 : normalizedSource.length)}...');
            final cachedLines = await file.openRead().transform(utf8.decoder).transform(const LineSplitter()).toList();
            if (cachedLines.isNotEmpty) {
              print('✅ M3uService: Usando cache local válido (${cachedLines.length} linhas)');
              return cachedLines;
            } else {
              print('⚠️ M3uService: Cache existe mas está vazio. Baixando novamente...');
            }
          } else {
            // URL não corresponde - deleta cache antigo
            print('⚠️ M3uService: Cache existe mas URL NÃO corresponde! Deletando cache antigo...');
            print('   URL solicitada: ${normalizedSource.substring(0, normalizedSource.length > 50 ? 50 : normalizedSource.length)}...');
            print('   URL salva: ${normalizedSaved.substring(0, normalizedSaved.length > 50 ? 50 : normalizedSaved.length)}...');
            try {
              await file.delete();
              print('🗑️ M3uService: Cache antigo deletado (URL não corresponde)');
            } catch (e) {
              print('⚠️ M3uService: Erro ao deletar cache antigo: $e');
            }
          }
        } else {
          print('ℹ️ M3uService: Cache não existe para esta URL. Baixando...');
        }
      } catch (e) {
        print('⚠️ M3uService: Erro ao verificar cache local: $e');
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
        // CRÍTICO: Só tenta usar cache se download falhar E a URL corresponder
        // NUNCA usa cache de URL diferente
        if (normalizedSaved.isNotEmpty && normalizedSource == normalizedSaved) {
          try {
            final file = await cacheFile();
            if (await file.exists()) {
              final cachedLines = await file.openRead().transform(utf8.decoder).transform(const LineSplitter()).toList();
              if (cachedLines.isNotEmpty) {
                print('💾 M3uService: Usando cache após erro de download (${cachedLines.length} linhas) - URL corresponde');
                return cachedLines;
              }
            }
          } catch (cacheError) {
            print('⚠️ M3uService: Erro ao ler cache após falha de download: $cacheError');
          }
        } else {
          print('⚠️ M3uService: Não usando cache após erro (URL não corresponde ou não há URL salva)');
        }
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
    final attrs = <String, String>{};

    // Regex robusto para atributos M3U: chave="valor com espaços" ou chave=valor_sem_aspas
    // Suporta hífens e underscores nas chaves.
    final regex = RegExp(r'([\w\-_]+)\s*=\s*(?:"([^"]*)"|([^,\s]*))');
    
    for (final m in regex.allMatches(extInf)) {
      final key = m.group(1)?.toLowerCase() ?? '';
      final value = (m.group(2) ?? m.group(3) ?? '').trim();
      if (key.isNotEmpty) {
        attrs[key] = value;
      }
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
    
    // Tenta múltiplos campos para imagem (ordem de prioridade)
    // Verifica todas as variações possíveis do M3U
    var logo = meta['tvg-logo'] ?? 
               meta['tvg_logo'] ??
               meta['logo'] ?? 
               meta['Logo'] ?? 
               meta['cover'] ?? 
               meta['Cover'] ?? 
               meta['image'] ?? 
               meta['Image'] ?? 
               meta['poster'] ??
               meta['Poster'] ??
               meta['thumbnail'] ??
               meta['Thumbnail'] ??
               '';
    
    // Limpa espaços e valida URL básica
    logo = logo.trim();
    // Se não começa com http/https, pode ser caminho relativo - mantém como está
    // Remove apenas se estiver completamente vazio ou só espaços
    if (logo.isEmpty) {
      logo = '';
    }
    
    final type = _inferType(group, title);
    final quality = _inferQuality(title, group);
    final audioType = _inferAudioType(title);
    final year = _extractYear(title);

    return ContentItem(
      title: title,
      url: url,
      image: logo,
      group: group,
      type: type,
      isSeries: type == 'series',
      quality: quality,
      audioType: audioType,
      year: year,
    );
  }

  static String _inferType(String group, String title) {
    final g = group.toLowerCase();
    final t = title.toLowerCase();

    // === HEURÍSTICAS DE SEGMENTAÇÃO MELHORADAS ===
    // ORDEM DE PRIORIDADE (do mais específico ao mais genérico)

        // 🔴 REGRA -1 (PRIORIDADE MÁXIMA) REVISADA: "FILMES | SÉRIES"
        // Antes tratávamos sempre como CANAL, mas isso causa muitos falsos positivos
        // (listas que usam este rótulo para agrupar filmes e séries). Agora só
        // considera CANAL se o título indicar claramente streaming/ao-vivo ou
        // terminar com um número curto indicando um canal numerado (ex: "Netflix 1").
        if (g.contains('filmes | séries') || g.contains('filmes | series') ||
            g.contains('filmes|séries') || g.contains('filmes|series')) {
          final lowerTitle = t;
          // Se o título indica live/stream/24h ou termina com número (canal numerado),
          // então é provável que se trate de um canal
          if (lowerTitle.contains('live') || lowerTitle.contains('ao vivo') ||
              lowerTitle.contains('24h') || RegExp(r'\b\d{1,3}\$').hasMatch(lowerTitle) || RegExp(r'\s\d{1,3}\$').hasMatch(lowerTitle)) {
            return 'channel';
          }
          // Caso contrário: se NÃO tem padrão de série (S##E##), retorna 'movie'
          // Isso evita que itens genéricos de "FILMES | SÉRIES" sejam forçados para 'series'
          if (!RegExp(r's\d{2}e\d{2}|season\s*\d+|temporada\s*\d+|episódio\s*\d+').hasMatch(lowerTitle)) {
            return 'movie'; // Sem padrão de série → assume filme
          }
          // Se TEM padrão de série, deixa as próximas heurísticas (regra 3) confirmarem
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

    // 🔵 REGRA 8: Filmes explícitos (Prioridade sobre plataformas)
    if (g.contains('filme') || g.contains('movie') || g.contains('movies') ||
        g.contains('cinema') || g.contains('lançamento') || g.contains('réelshort')) {
      return 'movie';
    }

    // 🔵 REGRA 9: Gêneros de filme
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

    // 🔵 REGRA 10: Top 10 / Destaques
    if (g.contains('top 10') || g.contains('sessão da tarde') ||
        g.contains('destaque') || g.contains('bestseller')) {
      return 'movie';
    }

    // 🟡 REGRA 11: Categorias explícitas de séries
    if (g.contains('série') || g.contains('serie') || g.contains('series') || 
        g.contains('anime') || g.contains('desenho') || g.contains('novela') ||
        g.contains('dorama') || g.contains('tokusatsu') ||
        g.contains('reelshort') || g.contains('cursos') ||
        g.contains('brasil paralelo') || g.contains('fitness') ||
        g.contains('shows nacionais') || g.contains('shows internacionais') ||
        g.contains('reality show')) {
      return 'series';
    }

    // 🟡 REGRA 12: Plataformas de streaming (Netflix, HBO, etc) = SÉRIE (Fallback)
    // Se não foi identificado como filme explicitamente acima, assume série para estas categorias
    if (g.contains('netflix') || g.contains('globo play') || 
        g.contains('amazon prime video') || g.contains('amazon prime') ||
        g.contains('disney+') || g.contains('hbo max') || g.contains('hbo') ||
        g.contains('paramount+') || g.contains('paramount') ||
        g.contains('apple tv+') || g.contains('apple tv') ||
        g.contains('star+') || g.contains('star plus') ||
        g.contains('starz') || g.contains('discovery+')) {
      return 'series';
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

  static String _extractYear(String title) {
    if (title.isEmpty) return "";
    
    // Procura por (YYYY)
    final regex = RegExp(r'\((\d{4})\)');
    final match = regex.firstMatch(title);
    if (match != null) return match.group(1)!;
    
    // Procura por [YYYY]
    final regexBrackets = RegExp(r'\[(\d{4})\]');
    final matchBrackets = regexBrackets.firstMatch(title);
    if (matchBrackets != null) return matchBrackets.group(1)!;
    
    // Procura por ano solto no final 19XX ou 20XX
    final regexEnd = RegExp(r'\b(19\d{2}|20\d{2})\b');
    final matches = regexEnd.allMatches(title).toList();
    if (matches.isNotEmpty) {
      return matches.last.group(1)!;
    }
    
    return "";
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

    // 1. Remove tudo entre colchetes e chaves (ex: [FHD], {LEG}, [Dual])
    base = base.replaceAll(RegExp(r'\[.*?\]'), '');
    base = base.replaceAll(RegExp(r'\{.*?\}'), '');
    
    // 2. Remove padrões de Temporada/Episódio variados
    // S01E01, S01 E01, s01e01
    base = base.replaceAll(RegExp(r'\bS\d{1,2}\s*E\d{1,2}\b', caseSensitive: false), ' ');
    // T01E01, T01 E01
    base = base.replaceAll(RegExp(r'\bT\d{1,2}\s*E\d{1,2}\b', caseSensitive: false), ' ');
    // 1x01, 01x01
    base = base.replaceAll(RegExp(r'\b\d{1,2}x\d{1,2}\b'), ' ');
    // Season 1, Temporada 1
    base = base.replaceAll(RegExp(r'\b(season|temporada)\s*\d+', caseSensitive: false), ' ');
    // Ep 01, Episodio 01
    base = base.replaceAll(RegExp(r'\b(ep|epis[oó]dio)\s*\d+', caseSensitive: false), ' ');
    
    // 3. Remove (Ano) - ex: (2023)
    base = base.replaceAll(RegExp(r'\(\d{4}\)'), ' ');
    
    // 4. Remove marcadores de qualidade e idioma comuns fora de colchetes
    base = base.replaceAll(RegExp(r'\b(FHD|HD|SD|4K|UHD|H265|HEVC|1080p|720p|480p)\b', caseSensitive: false), ' ');
    base = base.replaceAll(RegExp(r'\b(DUBLADO|LEGENDADO|LEG|DUB|DUAL)\b', caseSensitive: false), ' ');

    // 5. Limpeza final de pontuação e espaços
    // Remove caracteres especiais isolados que sobraram
    base = base.replaceAll(RegExp(r'\s+[\-\|:]+\s+'), ' '); // Remove separadores soltos no meio
    base = base.replaceAll(RegExp(r'[\.\-_\|\:]+$'), ''); // Remove pontuação no final
    
    // Normaliza espaços múltiplos
    base = base.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return base.isEmpty ? title : base;
  }

  /// Garante cache de filmes em memória e usa compute para parse em isolate.
  static Future<void> _ensureMovieCache({required String source, int maxItems = 999999}) async {
    // EARLY RETURN: Se o cache já está carregado e é da mesma source, não faz nada
    if (_seriesCache != null && 
        _seriesCache!.isNotEmpty && 
        _movieCacheSource == source) {
      print('⚡ _ensureMovieCache: Cache já pronto (${_seriesCache!.length} séries). Skip!');
      return;
    }
    
    // CRÍTICO: Verifica se há playlist válida ANTES de carregar cache
    final savedUrl = Config.playlistRuntime;
    if (savedUrl == null || savedUrl.isEmpty) {
      print('⚠️ M3uService: _ensureMovieCache - Sem playlist configurada, limpando TODOS os caches');
      clearMemoryCache(); // Limpa completamente
      _movieCache = null;
      _seriesCache = null;
      _channelCache = null;
      _movieCacheSource = null;
      _movieCacheMaxItems = 0;
      _preloadDone = false;
      _preloadSource = null;
      return;
    }
    
    // Se não há playlist definida na source, LIMPA todos os caches e retorna vazio
    if (source.isEmpty || source.trim().isEmpty) {
      print('⚠️ M3uService: Source vazia - limpando TODOS os caches');
      clearMemoryCache(); // Limpa completamente
      _movieCache = null;
      _seriesCache = null;
      _channelCache = null;
      _movieCacheSource = null;
      _movieCacheMaxItems = 0;
      _preloadDone = false;
      _preloadSource = null;
      return;
    }
    
    // CRÍTICO: Verifica se a source corresponde à playlist salva
    final normalizedSource = source.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedSaved = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalizedSource != normalizedSaved) {
      print('⚠️ M3uService: _ensureMovieCache - Source não corresponde à playlist salva!');
      print('   Source: ${normalizedSource.substring(0, normalizedSource.length > 50 ? 50 : normalizedSource.length)}');
      print('   Salva: ${normalizedSaved.substring(0, normalizedSaved.length > 50 ? 50 : normalizedSaved.length)}');
      clearMemoryCache();
      _movieCache = null;
      _seriesCache = null;
      _channelCache = null;
      _movieCacheSource = null;
      return;
    }

    // Verificação de preload em andamento
    final preloadKey = source.trim();
    if (_preloadCompleters.containsKey(preloadKey) && !isPreloaded(source)) {
      // Se já temos a lista carregada em memória (cache pronto), não precisamos esperar.
      if (_movieCache != null || _seriesCache != null || _channelCache != null) {
        return;
      }

      print('⏳ M3uService: fetch solicitou itens, mas parse ainda em curso. Aguardando...');
      try {
        // Aguarda o término do parse em andamento (com timeout de segurança)
        await _preloadCompleters[preloadKey]!.future.timeout(const Duration(seconds: 15));
      } catch (e) {
        print('⚠️ M3uService: Timeout aguardando parse completo. Prosseguindo com o que temos.');
      }
    }

    final key = '$source::$maxItems';
    if (_pendingCacheEnsures.containsKey(key)) {
      await _pendingCacheEnsures[key];
      return;
    }

    // Sem limite artificial - carrega tudo se for para categorias
    final safeLimit = maxItems;

    final future = () async {
    final file = await _getCacheFile(source); // Get the cache file for the source
    if (!await file.exists()) {
      print('⚠️ M3uService: Cache não encontrado para _ensureMovieCache');
      return;
    }

    final parsedMaps = await compute(_parseFileIsolate, {
      'path': file.path, // Pass the file path to the isolate
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
          year: m['year'] ?? '',
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

      // CRÍTICO: Só atualiza o cache se esta versão tem MAIS itens que a atual
      // Isso evita que caches parciais sobrescrevam o cache completo
      final currentMovieCount = _movieCache?.length ?? 0;
      final currentSeriesCount = _seriesCache?.length ?? 0;
      final currentChannelCount = _channelCache?.length ?? 0;
      
      if (movies.length >= currentMovieCount && 
          series.length >= currentSeriesCount && 
          channels.length >= currentChannelCount) {
        
        _movieCache = movies;
        _seriesCache = series;
        _channelCache = channels;
        _movieCacheSource = source;
        _movieCacheMaxItems = safeLimit;
        
        print('✅ DEBUG: Cache ATUALIZADO - movies=${movies.length} (era $currentMovieCount), series=${series.length} (era $currentSeriesCount), channels=${channels.length} (era $currentChannelCount)');
      } else {
        print('⚠️ DEBUG: Cache NÃO atualizado - tentativa de sobrescrever cache maior com menor! movies=${movies.length} vs $currentMovieCount, series=${series.length} vs $currentSeriesCount');
        return; // NÃO sobrescreve
      }
      
      _movieCategoryCounts = counts;
      _movieCategories = cats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _movieCategoryThumb = thumbs;
      
      _seriesCategoryCounts = sCounts;
      _seriesCategories = sCats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _seriesCategoryThumb = sThumbs;
      
      _channelCategoryCounts = cCounts;
      _channelCategories = cCats.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _channelCategoryThumb = cThumbs;
      
      // CRÍTICO: Salva meta-cache no disco após parse bem sucedido para persistir categorias
      await _saveMetaCache(source);
      
      print('📊 M3uService Cache Atualizado: ${movies.length} filmes, ${series.length} séries, ${channels.length} canais');
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
      // CRÍTICO: Enriquecimento em background RE-ATIVADO, MAS com proteção total do grupo/categoria
      // O enriquecimento APENAS adiciona metadados (rating, descrição, gênero)
      // NUNCA modifica: title, url, group, type, isSeries
      (() async {
        try {
          final sampleSize = movies.length < 200 ? movies.length : 200;
          if (sampleSize == 0) return;
          print('🔍 M3uService: Background enrichment TMDB (sample $sampleSize) - PROTEGENDO categorias originais...');
          final sample = _movieCache!.take(sampleSize).toList();
          final enriched = await ContentEnricher.enrichItems(sample);
          
          // CRÍTICO: Aplica APENAS se o grupo não mudou
          int updated = 0;
          for (var i = 0; i < enriched.length && i < sample.length; i++) {
            final original = sample[i];
            final enrichedItem = enriched[i];
            
            // VALIDAÇÃO: Garante que campos críticos não mudaram
            if (enrichedItem.title == original.title &&
                enrichedItem.url == original.url &&
                enrichedItem.group == original.group &&
                enrichedItem.type == original.type) {
              
              // OK para aplicar - categoria preservada
              if (enrichedItem.rating > 0 || (enrichedItem.description.isNotEmpty && enrichedItem.description != original.description)) {
                _movieCache![i] = enrichedItem;
                updated++;
              }
            } else {
              print('⚠️ TMDB: Item "${original.title}" teve alteração em campos críticos - IGNORANDO enriquecimento para preservar integridade');
            }
          }
          print('✅ M3uService: Background enrichment concluído ($updated atualizados, categorias preservadas)');
        } catch (e, st) {
          print('⚠️ M3uService: Erro no background enrichment: $e');
          print(st);
        }
      })();
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
    print('🔍 fetchCategoryItemsFromEnv: category="$category", typeFilter="$typeFilter"');
    
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: fetchCategoryItemsFromEnv - Sem URL configurada, retornando lista vazia');
      // CRÍTICO: Limpa cache se não há playlist
      clearMemoryCache();
      return [];
    }

    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    // DEBUG: Estado do cache
    print('🔍 Cache state: _movieCache=${_movieCache?.length ?? "null"}, _seriesCache=${_seriesCache?.length ?? "null"}, _channelCache=${_channelCache?.length ?? "null"}');
    
    // Se o cache global tem menos itens do que o solicitado e não é o cache completo (9999),
    // pode ser necessário aguardar ou re-priorizar.
    if (_movieCache == null && _seriesCache == null && _channelCache == null) {
      print('ℹ️ M3uService: fetchCategoryItemsFromEnv - Cache ainda não pronto.');
      return [];
    }

    final normalized = category.trim().toLowerCase();
    
    // Busca no cache correto
    final base = (typeFilter == 'series')
        ? (_seriesCache ?? [])
        : (typeFilter == 'channel')
            ? (_channelCache ?? [])
            : (_movieCache ?? []);
    
    if (base.isEmpty && !isPreloaded(source)) {
       print('⏳ fetchCategoryItemsFromEnv: Cache de $typeFilter vazio, mas preload em curso...');
    }
    
    final filtered = base
      .where((e) => e.group.trim().toLowerCase() == normalized)
      .toList();
    
    // Debug: verifica quantos itens têm imagem
    final withImage = filtered.where((e) => e.image.isNotEmpty).length;
    print('📂 fetchCategoryItemsFromEnv($category, $typeFilter): ${filtered.length} itens, ${withImage} com imagem');
    
    if (withImage == 0 && filtered.isNotEmpty) {
      print('⚠️ fetchCategoryItemsFromEnv: Nenhum item tem imagem! Primeiro item: ${filtered.first.title}, image: "${filtered.first.image}"');
    }
    
    return filtered;
  }

  /// Retorna um mapa categoria -> thumb (primeira imagem encontrada) e contagens.
  static Future<M3uCategoryMeta> fetchCategoryMetaFromEnv({
    String typeFilter = 'movie',
    int maxItems = 999999,
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: fetchCategoryMetaFromEnv - Sem URL configurada, retornando vazio');
      // Retorna meta vazio ao invés de lançar exceção
      return const M3uCategoryMeta(categories: [], counts: {}, thumbs: {});
    }

    // Se já temos meta-dados (nomes das categorias e contagens) carregados no cache 
    // ou via meta-cache persistente, retornamos IMEDIATAMENTE.
    // Isso é FUNDAMENTAL para a Home abrir instantaneamente.
    if (_movieCacheSource == source && 
        ((typeFilter == 'movie' && _movieCategories.isNotEmpty) ||
         (typeFilter == 'series' && _seriesCategories.isNotEmpty) ||
         (typeFilter == 'channel' && _channelCategories.isNotEmpty))) {
      print('⚡ M3uService: fetchCategoryMetaFromEnv - Retornando categorias de cache instantaneamente');
      
      // DISPARA o _ensureMovieCache em background caso o cache total de ITENS ainda não exista
      // Isso garante que quando o usuário clicar em uma categoria, o parse já esteja adiantado.
      _ensureMovieCache(source: source, maxItems: maxItems).catchError((e) => print('⚠️ Background cache fail: $e'));
    } else {
      // Se não temos NADA em memória, aí sim esperamos o parse.
      await _ensureMovieCache(source: source, maxItems: maxItems);
    }
    if (typeFilter == 'series') {
      return M3uCategoryMeta(categories: _seriesCategories, counts: _seriesCategoryCounts, thumbs: _seriesCategoryThumb);
    }
    if (typeFilter == 'channel') {
      return M3uCategoryMeta(categories: _channelCategories, counts: _channelCategoryCounts, thumbs: _channelCategoryThumb);
    }
    return M3uCategoryMeta(categories: _movieCategories, counts: _movieCategoryCounts, thumbs: _movieCategoryThumb);
  }

  // Cache de agregação de séries (para não reagregar toda vez)
  static final Map<String, List<ContentItem>> _seriesAggregationCache = {};
  
  /// Retorna uma lista agregada por série (título base) para a categoria informada.
  /// Útil para navegar primeiro por séries, depois abrir temporadas/episódios na tela de detalhes.
  static Future<List<ContentItem>> fetchSeriesAggregatedForCategory({
    required String category,
    int maxItems = 999999,
  }) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: fetchSeriesAggregatedForCategory - Sem URL configurada, retornando lista vazia');
      return [];
    }
    
    // Verifica cache de agregação primeiro
    final cacheKey = '${source}_$category';
    if (_seriesAggregationCache.containsKey(cacheKey)) {
      print('✅ fetchSeriesAggregatedForCategory: Usando cache para \"$category\"');
      return _seriesAggregationCache[cacheKey]!;
    }
    
    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    // SE cache é null, retorna lista vazia
    if (_seriesCache == null) {
      print('⚠️ M3uService: fetchSeriesAggregatedForCategory - Cache é null, retornando lista vazia');
      return [];
    }
    
    final normalized = category.trim().toLowerCase();
    
    // Normalização agressiva para evitar problemas de matching
    String normalize(String text) {
      return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')  // Múltiplos espaços -> um espaço
        .replaceAll(RegExp(r'[^\w\s]'), ''); // Remove caracteres especiais
    }
    
    final normalizedCategory = normalize(category);
    
    print('🔍 fetchSeriesAggregatedForCategory: "$category" (normalizado: "$normalizedCategory")');
    print('   Cache tem ${_seriesCache?.length ?? 0} séries totais');
    
    // Filtragem com matching mais flexível
    final list = _seriesCache!
        .where((e) {
          final itemGroup = normalize(e.group);
          // Tenta match exato primeiro
          if (itemGroup == normalizedCategory) return true;
          // Se não deu match exato, tenta contains (para casos como "Netflix HD" vs "Netflix")
          if (itemGroup.contains(normalizedCategory) || normalizedCategory.contains(itemGroup)) return true;
          return false;
        })
        .toList();
    
    print('   Encontrou ${list.length} episódios na categoria "$category"');
        
    final map = <String, ContentItem>{};
    for (final it in list) {
      final baseTitle = extractSeriesBaseTitle(it.title);
      if (!map.containsKey(baseTitle)) {
        String cover = '';
        if (it.image.isNotEmpty) {
          cover = it.image;
        } else {
          // Busca em outros episódios da MESMA série DENTRO desta categoria
          final seriesEpisodes = list.where(
            (x) => extractSeriesBaseTitle(x.title) == baseTitle && x.image.isNotEmpty
          ).toList();
          if (seriesEpisodes.isNotEmpty) {
            cover = seriesEpisodes.first.image;
          }
        }
        
        map[baseTitle] = ContentItem(
          title: baseTitle,
          url: it.url, 
          image: cover,
          group: it.group,
          type: 'series',
          isSeries: true,
          quality: it.quality,
          audioType: it.audioType,
        );
      } else {
        // Se já existe, atualiza a imagem se a atual for melhor (não vazia)
        final existing = map[baseTitle]!;
        if (existing.image.isEmpty && it.image.isNotEmpty) {
          map[baseTitle] = ContentItem(
            title: existing.title,
            url: existing.url,
            image: it.image,
            group: existing.group,
            type: existing.type,
            isSeries: existing.isSeries,
            quality: existing.quality,
            audioType: existing.audioType,
          );
        }
      }
    }
    
    final aggregated = map.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    
    // Salva no cache de agregação para próximas consultas
    _seriesAggregationCache[cacheKey] = aggregated;
    
    print('✅ fetchSeriesAggregatedForCategory retornando ${aggregated.length} séries para "$category" (cached)');
    
    return aggregated;
  }

  /// Retorna os "últimos filmes" com base na ordem da playlist (assumindo que a
  /// fonte lista adições recentes no topo). Limita por [count].
  static Future<List<ContentItem>> getLatestMovies({int count = 20, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: getLatestMovies - Sem URL configurada, retornando lista vazia');
      return [];
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    final list = _movieCache ?? const <ContentItem>[];
    return list.take(count).toList();
  }

  /// Seleção determinística diária de destaques com viés para melhor qualidade e com imagem.
  /// Usa um pool inicial dos itens mais recentes e faz uma seleção baseada em seed.
  static Future<List<ContentItem>> getDailyFeaturedMovies({int count = 6, int pool = 80, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: getDailyFeaturedMovies - Sem URL configurada, retornando lista vazia');
      return [];
    }
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
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: getLatestByType - Sem URL configurada, retornando lista vazia');
      clearMemoryCache();
      return [];
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    // CRÍTICO: Se cache é null, retorna lista vazia
    if (_movieCache == null && _seriesCache == null && _channelCache == null) {
      print('⚠️ M3uService: getLatestByType - Cache é null, retornando lista vazia');
      return [];
    }
    
    final list = type == 'series'
        ? (_seriesCache ?? const <ContentItem>[])
        : type == 'channel'
            ? (_channelCache ?? const <ContentItem>[])
            : (_movieCache ?? const <ContentItem>[]);
    return list.take(count).toList();
  }

  static Future<List<ContentItem>> getDailyFeaturedByType(String type, {int count = 6, int pool = 80, int maxItems = 999999}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: getDailyFeaturedByType - Sem URL configurada, retornando lista vazia');
      return [];
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    // CRÍTICO: Se cache é null, retorna lista vazia
    if (_movieCache == null && _seriesCache == null && _channelCache == null) {
      print('⚠️ M3uService: getDailyFeaturedByType - Cache é null, retornando lista vazia');
      return [];
    }
    
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
    if (source == null || source.isEmpty) {
      print('⚠️ M3uService: getCuratedFeaturedPrefer - Sem URL configurada, retornando lista vazia');
      return [];
    }
    await _ensureMovieCache(source: source, maxItems: maxItems);
    
    // CRÍTICO: Se cache é null, retorna lista vazia
    if (_movieCache == null && _seriesCache == null && _channelCache == null) {
      print('⚠️ M3uService: getCuratedFeaturedPrefer - Cache é null, retornando lista vazia');
      return [];
    }

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
    int i = 0;
    for (final item in (_movieCache ?? [])) {
      if (results.length >= maxResults) break;
      if (++i % 500 == 0) await Future.delayed(Duration.zero); // Yield para UI
      
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        results.add(item);
      }
    }
    
    // Buscar em séries
    final seenSeries = <String>{};
    i = 0;
    for (final item in (_seriesCache ?? [])) {
      if (results.length >= maxResults) break;
      if (++i % 500 == 0) await Future.delayed(Duration.zero); // Yield
      
      final baseTitle = extractSeriesBaseTitle(item.title).toLowerCase();
      if (seenSeries.contains(baseTitle)) continue;
      
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        seenSeries.add(baseTitle);
        // Cria um item representando a SÉRIE, não o episódio
        results.add(ContentItem(
          title: baseTitle, // Título limpo da série
          url: item.url,
          image: item.image,
          group: item.group,
          type: 'series',
          isSeries: true, // Garante flag de série
          rating: item.rating,
          year: item.year,
          quality: item.quality,
          audioType: item.audioType,
          description: item.description,
          genre: item.genre,
        ));
      }
    }
    
    // Buscar em canais
    i = 0;
    for (final item in (_channelCache ?? [])) {
      if (results.length >= maxResults) break;
      if (++i % 500 == 0) await Future.delayed(Duration.zero); // Yield
      
      if (item.title.toLowerCase().contains(q) || item.group.toLowerCase().contains(q)) {
        results.add(item);
      }
    }
    
    return results;
  }

  /// Busca detalhes de uma série agrupando episódios por temporada
  static Future<SeriesDetails?> fetchSeriesDetailsFromM3u(String seriesTitle, String category, {String? audioType, int maxItems = 500, String? originalTitle}) async {
    final source = Config.playlistRuntime;
    if (source == null || source.isEmpty) return null;

    // CRÍTICO: Carrega TODO o cache (999k itens) se necessário, não apenas 'maxItems' (que é para o retorno)
    // Se passarmos maxItems aqui (ex: 150), ele carrega só 150 linhas do arquivo M3U!
    await _ensureMovieCache(source: source, maxItems: 999999);

    // Normaliza e usa o título base para evitar misturar séries diferentes
    final targetBase = extractSeriesBaseTitle(seriesTitle).toLowerCase();
    // Título original como alternativa de busca (ex: "House of Cards" vs "House of Cards - EUA")
    final originalBase = originalTitle != null && originalTitle.isNotEmpty 
        ? extractSeriesBaseTitle(originalTitle).toLowerCase() 
        : null;
    final normalizedCat = category.trim().toLowerCase();
    final isTmdbSource = category.contains('TMDB');

    // OTIMIZAÇÃO MAXIMA: Varredura única na lista gigante (pode ter 200k+ itens)
    // Em vez de percorrer a lista 3 vezes (Exata, Título, Fuzzy), percorremos 1 vez e separamos.
    
    final exactMatches = <ContentItem>[];
    final titleMatches = <ContentItem>[];
    final fuzzyMatches = <ContentItem>[];
    
    final cacheList = _seriesCache ?? [];
    print('🔍 fetchSeriesDetailsFromM3u: Buscando "$seriesTitle"${originalBase != null ? " (original: $originalTitle)" : ""} em ${cacheList.length} itens...');
    
    final stopwatch = Stopwatch()..start();

    // Loop otimizado
    for (var i = 0; i < cacheList.length; i++) {
        final item = cacheList[i];
        
        // Extração de base title pode ser custosa, fazemos sob demanda
        final itemTitleBase = extractSeriesBaseTitle(item.title).toLowerCase();
        
        // 1. Verifica Título Base (Comum a todas as estratégias) - filtro rápido primeiro
        // Compara com targetBase E originalBase (se disponível)
        
        // Estratégia de prioridade:
        
        // Match exato por categoria + título (ou título original)
        if (!isTmdbSource && item.group.trim().toLowerCase() == normalizedCat) {
           if (itemTitleBase == targetBase || (originalBase != null && itemTitleBase == originalBase)) {
              exactMatches.add(item);
              continue;
           }
        }
        
        // Match por título exato (ignora categoria)
        if (itemTitleBase == targetBase || (originalBase != null && itemTitleBase == originalBase)) {
           titleMatches.add(item);
           continue;
        }
        
        // Fuzzy: Verifica se título contém ou é contido (apenas se targetBase for grande o suficiente)
        if (targetBase.length > 3) {
           if (itemTitleBase.contains(targetBase) || targetBase.contains(itemTitleBase)) {
              fuzzyMatches.add(item);
              continue;
           }
           // Tenta fuzzy com título original também
           if (originalBase != null && originalBase.length > 3) {
              if (itemTitleBase.contains(originalBase) || originalBase.contains(itemTitleBase)) {
                 fuzzyMatches.add(item);
              }
           }
        }
        
        // Limite de segurança para não estourar memória se houver MILHARES de matches
        if (exactMatches.length + titleMatches.length + fuzzyMatches.length > 2000) {
            break; 
        }
    }
    
    stopwatch.stop();
    print('⏱️ Varredura concluída em ${stopwatch.elapsedMilliseconds}ms');

    // Decide qual lista usar (pela ordem de qualidade)
    var allEpisodes = <ContentItem>[];
    
    if (exactMatches.isNotEmpty) {
       print('✅ Usando Match Exato (${exactMatches.length} eps)');
       allEpisodes = exactMatches;
    } else if (titleMatches.isNotEmpty) {
       print('✅ Usando Match por Título (${titleMatches.length} eps)');
       allEpisodes = titleMatches;
    } else if (fuzzyMatches.isNotEmpty) {
       print('✅ Usando Match Fuzzy (${fuzzyMatches.length} eps)');
       allEpisodes = fuzzyMatches;
    }

    if (allEpisodes.isEmpty) return null;

    // Limita após escolher o melhor grupo
    if (allEpisodes.length > maxItems) {
       allEpisodes = allEpisodes.sublist(0, maxItems);
    }

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
    
    // Se não encontrou temporadas organizadas, retorna null
    if (seasonMap.isEmpty) {
      print('⚠️ fetchSeriesDetailsFromM3u: Nenhuma temporada encontrada para "$seriesTitle"');
      return null;
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

    print('✅ fetchSeriesDetailsFromM3u: "$seriesTitle" - ${seasonMap.length} temporadas, ${allEpisodes.length} episódios');

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

/// Isolate para parsear o arquivo M3U diretamente do disco usando Streams.
/// Isso é FUNDAMENTAL para não estourar a memória (OOM) no Fire Stick/TVs.
Future<List<Map<String, String>>> _parseFileIsolate(Map<String, dynamic> args) async {
  final String path = args['path'];
  final int limit = args['limit'] as int? ?? 500000;

  final results = <Map<String, String>>[];
  
  try {
    final file = File(path);
    if (!await file.exists()) return [];

    String? pendingExtInf;
    String? lastExtGrp;
    int movieCount = 0, seriesCount = 0, channelCount = 0;

    final stream = file.openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#EXTINF')) {
        pendingExtInf = trimmed;
        lastExtGrp = null; 
        continue;
      }

      if (trimmed.startsWith('#EXTGRP:')) {
        lastExtGrp = trimmed.substring(8).trim();
        continue;
      }

      if (pendingExtInf != null && !trimmed.startsWith('#')) {
        final meta = M3uService._parseExtInf(pendingExtInf);
        
        // PRIORIDADE 1: Atributo group-title dentro do EXTINF
        // PRIORIDADE 2: Tag #EXTGRP separada
        // PRIORIDADE 3: Fallback 'Geral'
        var groupTitle = meta['group-title'] ?? lastExtGrp ?? 'Geral';
        
        // Sanitização agressiva do nome do grupo (remove espaços extras e normaliza)
        groupTitle = groupTitle.trim();
        if (groupTitle.isEmpty) groupTitle = 'Geral';

        final title = (meta['title'] ?? meta['tvg-name'] ?? '').trim();
        
        if (title.isEmpty) {
          pendingExtInf = null;
          lastExtGrp = null;
          continue;
        }

        final type = M3uService._inferType(groupTitle, title);
        final quality = M3uService._inferQuality(title, groupTitle);
        final audioType = M3uService._inferAudioType(title);
        final year = M3uService._extractYear(title);
        
        if (type == 'movie') movieCount++;
        else if (type == 'series') seriesCount++;
        else channelCount++;
        
        final image = meta['tvg-logo'] ?? 
                      meta['tvg_logo'] ??
                      meta['logo'] ?? 
                      meta['cover'] ?? 
                      meta['image'] ?? 
                      meta['poster'] ??
                      meta['thumbnail'] ??
                      '';
        
        results.add({
          'title': title,
          'url': trimmed,
          'image': image.trim(),
          'group': groupTitle,
          'type': type,
          'quality': quality,
          'audioType': audioType,
          'year': year,
        });

        pendingExtInf = null;
        lastExtGrp = null;
        if (results.length >= limit) break;
      }
    }
    
    print('📊 Isolate Final: $movieCount filmes, $seriesCount séries, $channelCount canais (Suporte EXTGRP ativo)');
  } catch (e) {
    print('❌ Isolate Fatal Error: $e');
  }

  return results;
}

class M3uBuckets {
  final List<ContentItem> channels;
  final List<ContentItem> movies;
  final List<ContentItem> series;
  final Map<String, List<ContentItem>> byGroup;

  M3uBuckets({required this.channels, required this.movies, required this.series, required this.byGroup});
}
