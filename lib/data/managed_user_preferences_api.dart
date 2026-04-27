import '../core/api/api_client.dart';
import '../core/config.dart';

class ManagedUserPreferencesApi {
  static final ApiClient _apiClient = ApiClient();

  static bool get isEnabled => Config.useManagedAccess;

  static Future<Map<String, dynamic>?> fetchPreferences() async {
    if (!isEnabled) return null;

    try {
      final response = await _apiClient.get('/auth/preferences');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data['preferences'] as Map<String, dynamic>?;
      }
    } catch (_) {}

    return null;
  }

  static Future<void> savePreferences({
    List<Map<String, dynamic>>? favorites,
    List<Map<String, dynamic>>? watchedHistory,
    Map<String, dynamic>? settings,
  }) async {
    if (!isEnabled) return;

    final payload = <String, dynamic>{};
    if (favorites != null) payload['favorites'] = favorites;
    if (watchedHistory != null) payload['watchedHistory'] = watchedHistory;
    if (settings != null) payload['settings'] = settings;

    if (payload.isEmpty) return;

    try {
      await _apiClient.put('/auth/preferences', data: payload);
    } catch (_) {}
  }
}
