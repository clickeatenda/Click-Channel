import 'package:flutter/foundation.dart';

import 'config.dart';

class ClickChannelWebProxy {
  static bool get isManagedWeb =>
      kIsWeb && Config.useManagedAccess && Config.backendUrl.isNotEmpty;

  static String? managedAccessToken() {
    if (!kIsWeb) return null;

    final playlistToken = _tokenFromUrl(Config.playlistRuntime);
    if (playlistToken != null && playlistToken.isNotEmpty) {
      return playlistToken;
    }

    final inboundToken = Uri.base.queryParameters['access_token']?.trim() ??
        Uri.base.queryParameters['token']?.trim();
    if (inboundToken != null && inboundToken.isNotEmpty) {
      return inboundToken;
    }

    return null;
  }

  static String? accessTokenFromUrl(String? value) {
    return _tokenFromUrl(value);
  }

  static String resolveImageUrl(String sourceUrl) {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty || !isManagedWeb) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return trimmed;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'data' || scheme == 'blob') return trimmed;
    if (scheme != 'http' && scheme != 'https') return trimmed;
    if (_isBackendStreamPath(uri, 'image')) return trimmed;

    final token = managedAccessToken();
    if (token == null || token.isEmpty) return trimmed;

    return Uri.parse('${Config.backendUrl}/api/auth/stream/image')
        .replace(queryParameters: {
      'access_token': token,
      'upstream_url': trimmed,
    }).toString();
  }

  static bool isBackendPlaybackProxy(String sourceUrl) {
    if (!isManagedWeb) return false;

    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null || !uri.hasScheme) return false;

    return _isBackendStreamPath(uri, 'media') ||
        _isBackendStreamPath(uri, 'manifest.m3u8');
  }

  static String? _tokenFromUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;

    return uri.queryParameters['access_token']?.trim() ??
        uri.queryParameters['token']?.trim();
  }

  static bool _isBackendStreamPath(Uri uri, String endpoint) {
    final backend = Uri.tryParse(Config.backendUrl);
    if (backend == null) return false;

    final sameOrigin = uri.scheme == backend.scheme && uri.host == backend.host;
    if (!sameOrigin) return false;

    final backendPort = backend.hasPort ? backend.port : null;
    final uriPort = uri.hasPort ? uri.port : null;
    if (backendPort != uriPort) return false;

    return uri.path == '/api/auth/stream/$endpoint';
  }
}
