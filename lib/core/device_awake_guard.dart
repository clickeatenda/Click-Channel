import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DeviceAwakeGuard with WidgetsBindingObserver {
  DeviceAwakeGuard._();

  static final DeviceAwakeGuard instance = DeviceAwakeGuard._();

  Timer? _refreshTimer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    ensureEnabled();

    // Some Android TV/Box firmwares clear KEEP_SCREEN_ON after HDMI/launcher
    // interruptions, so refresh the lock while the app is alive.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ensureEnabled(),
    );
  }

  Future<void> ensureEnabled() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      debugPrint('Unable to enable wakelock: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ensureEnabled();
    }
  }

  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
  }
}
