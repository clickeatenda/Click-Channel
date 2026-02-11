import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Cache manager para imagens com limite de 100MB
class AppImageCacheManager {
  static const key = 'appImageCache';
  
  /// Limite máximo de cache em objetos (2000 imagens ≈ 100MB dependendo do tamanho)
  static const int maxObjects = 2000;

  static final BaseCacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      /// Limite máximo de objetos cache (em torno de 100MB para imagens típicas)
      maxNrOfCacheObjects: maxObjects,
      repo: JsonCacheInfoRepository(databaseName: key),
      // Fix REVERT: Voltando ao padrão pois alguns servidores REJEITAM o User-Agent 'Chrome' (Canais)
      fileService: HttpFileService(),
    ),
  );
}

/// Cliente HTTP customizado que adiciona um User-Agent de navegador
class _UserAgentClient extends http.BaseClient {
  final http.Client _inner;
  _UserAgentClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // User-Agent do Chrome no Windows para garantir compatibilidade com CDNs restritivos
    request.headers['User-Agent'] = 
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    return _inner.send(request);
  }
}
