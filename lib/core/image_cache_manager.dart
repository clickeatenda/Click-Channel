import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManager {
  static const key = 'appImageCache';

  static final BaseCacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 2000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
