import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clickchannel/core/prefs.dart';

void main() {
  test('Prefs set and clear playlist override', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();

    await Prefs.setPlaylistOverride('https://example.com/playlist.m3u');
    expect(Prefs.getPlaylistOverride(), 'https://example.com/playlist.m3u');

    await Prefs.setPlaylistOverride(null);
    expect(Prefs.getPlaylistOverride(), null);
  });
}
