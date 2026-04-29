import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceSessionContext {
  final String deviceId;
  final String deviceLabel;
  final String platform;

  const DeviceSessionContext({
    required this.deviceId,
    required this.deviceLabel,
    required this.platform,
  });
}

class DeviceSession {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'managed_device_id';
  static const _deviceLabelKey = 'managed_device_label';
  static const _platformKey = 'managed_device_platform';

  static Future<DeviceSessionContext> getOrCreate() async {
    final existingId = await _storage.read(key: _deviceIdKey);
    final existingLabel = await _storage.read(key: _deviceLabelKey);
    final existingPlatform = await _storage.read(key: _platformKey);

    if (existingId != null &&
        existingId.trim().isNotEmpty &&
        existingLabel != null &&
        existingLabel.trim().isNotEmpty &&
        existingPlatform != null &&
        existingPlatform.trim().isNotEmpty) {
      return DeviceSessionContext(
        deviceId: existingId,
        deviceLabel: existingLabel,
        platform: existingPlatform,
      );
    }

    final createdContext = await _createFreshContext();
    await _storage.write(key: _deviceIdKey, value: createdContext.deviceId);
    await _storage.write(key: _deviceLabelKey, value: createdContext.deviceLabel);
    await _storage.write(key: _platformKey, value: createdContext.platform);

    return createdContext;
  }

  static Future<DeviceSessionContext> _createFreshContext() async {
    final deviceId = _generateDeviceId();
    final deviceInfo = DeviceInfoPlugin();
    final platform = _resolvePlatformName();
    String deviceLabel = platform;

    try {
      if (kIsWeb) {
        final info = await deviceInfo.webBrowserInfo;
        deviceLabel = [
          info.browserName.name,
          info.platform ?? '',
        ].where((part) => part.trim().isNotEmpty).join(' - ');
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            deviceLabel = [
              info.manufacturer,
              info.model,
            ].where((part) => part.trim().isNotEmpty).join(' ');
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            deviceLabel = [
              info.name,
              info.model,
            ].where((part) => part.trim().isNotEmpty).join(' - ');
            break;
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            deviceLabel = [
              info.computerName,
              info.productName,
            ].where((part) => part.trim().isNotEmpty).join(' - ');
            break;
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            deviceLabel = [
              info.computerName,
              info.model,
            ].where((part) => part.trim().isNotEmpty).join(' - ');
            break;
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            deviceLabel = [
              info.prettyName,
              info.name,
            ].where((part) => part.trim().isNotEmpty).join(' - ');
            break;
          case TargetPlatform.fuchsia:
            deviceLabel = 'fuchsia-device';
            break;
        }
      }
    } catch (_) {
      deviceLabel = platform;
    }

    final normalizedLabel = deviceLabel.trim().isEmpty ? platform : deviceLabel.trim();

    return DeviceSessionContext(
      deviceId: deviceId,
      deviceLabel: normalizedLabel,
      platform: platform,
    );
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    final randomPart = List.generate(4, (_) => random.nextInt(0xFFFFFFFF))
        .map((value) => value.toRadixString(16).padLeft(8, '0'))
        .join();
    return 'cc-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$randomPart';
  }

  static String _resolvePlatformName() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
