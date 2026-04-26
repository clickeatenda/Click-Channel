import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache manager para imagens — DEVE estender ImageCacheManager para que
/// CachedNetworkImage aceite memCacheWidth/memCacheHeight sem assertion error.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'appImageCache';

  static const int maxObjects = 2000;

  static final AppImageCacheManager instance = AppImageCacheManager._();

  AppImageCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: maxObjects,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
