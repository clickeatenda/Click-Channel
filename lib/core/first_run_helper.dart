import 'package:flutter/foundation.dart';
import '../core/prefs.dart';
import '../data/m3u_service.dart';

/// Helper used to encapsulate first-run / restored-prefs cleanup logic.
class FirstRunHelper {
  /// If a playlist override exists but there are no cache files (likely restored
  /// from backup), clears the persisted override and returns true if a clear
  /// was performed.
  static Future<bool> clearOverrideIfNoCache() async {
    try {
      final saved = Prefs.getPlaylistOverride();
      if (saved == null || saved.trim().isEmpty) return false;
      final hasCache = await M3uService.hasAnyCache();
      if (!hasCache) {
        // clear persisted override
        await Prefs.setPlaylistOverride(null);
        await Prefs.setPlaylistReady(false);
        if (kDebugMode) print('FirstRunHelper: cleared restored playlist override');
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('FirstRunHelper: error while checking override: $e');
    }
    return false;
  }
}
