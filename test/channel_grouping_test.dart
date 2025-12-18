import 'package:flutter_test/flutter_test.dart';
import 'package:clickchannel/utils/channel_grouping.dart';
import 'package:clickchannel/models/content_item.dart';

void main() {
  test('groupChannelVariants groups items by title', () {
    final items = [
      ContentItem(title: 'Band SP', url: 'u1', image: '', group: 'BAND', type: 'channel', quality: 'fhd', audioType: ''),
      ContentItem(title: 'Band SP', url: 'u2', image: '', group: 'BAND', type: 'channel', quality: 'hd', audioType: ''),
      ContentItem(title: 'A&E FHD', url: 'u3', image: '', group: 'A&E', type: 'channel', quality: 'fhd', audioType: ''),
    ];

    final grouped = groupChannelVariants(items);
    expect(grouped.length, 2);
    expect(grouped['Band SP']!.length, 2);
    expect(grouped['A&E FHD']!.length, 1);
  });
}
