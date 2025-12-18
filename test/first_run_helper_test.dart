import 'package:flutter_test/flutter_test.dart';
import 'package:clickchannel/core/first_run_helper.dart';
import 'package:clickchannel/data/m3u_service.dart';
import 'package:clickchannel/core/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clearOverrideIfNoCache clears override when no cache present', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.playlist_url_override': 'https://example.com/playlist.m3u',
    });
    await Prefs.resetForTests();

    // Force M3uService.hasAnyCache to return false via test override
    M3uService.setTestHasAnyCache(() => false);

    final cleared = await FirstRunHelper.clearOverrideIfNoCache();
    expect(cleared, true);
    expect(Prefs.getPlaylistOverride(), null);

    // reset override
    M3uService.setTestHasAnyCache(null);
  });

  test('clearOverrideIfNoCache does nothing if cache present', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.playlist_url_override': 'https://example.com/playlist.m3u',
    });
    await Prefs.resetForTests();

    M3uService.setTestHasAnyCache(() => true);
    final cleared = await FirstRunHelper.clearOverrideIfNoCache();
    expect(cleared, false);
    expect(Prefs.getPlaylistOverride(), 'https://example.com/playlist.m3u');
    M3uService.setTestHasAnyCache(null);
  });
}
