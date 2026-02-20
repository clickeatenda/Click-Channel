import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
      fileService: HttpFileService(),
    ),
  );
}
