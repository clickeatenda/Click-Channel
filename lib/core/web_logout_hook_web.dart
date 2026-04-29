import 'dart:async';
import 'dart:html' as html;

StreamSubscription<html.Event>? _beforeUnloadSubscription;

void registerManagedWebLogoutHook(String backendUrl, String token) {
  unregisterManagedWebLogoutHook();

  final normalizedBackendUrl = backendUrl.trim().replaceAll(RegExp(r'/$'), '');
  final trimmedToken = token.trim();
  if (normalizedBackendUrl.isEmpty || trimmedToken.isEmpty) return;

  final logoutUrl = '$normalizedBackendUrl/api/auth/logout?access_token=${Uri.encodeComponent(trimmedToken)}';

  _beforeUnloadSubscription = html.window.onBeforeUnload.listen((_) {
    try {
      html.window.navigator.sendBeacon(logoutUrl, '');
    } catch (_) {}
  });
}

void unregisterManagedWebLogoutHook() {
  _beforeUnloadSubscription?.cancel();
  _beforeUnloadSubscription = null;
}
