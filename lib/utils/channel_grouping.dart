import '../models/content_item.dart';

// Agrupa canais por título base (agrupa variantes de qualidade com mesmo nome)
Map<String, List<ContentItem>> groupChannelVariants(List<ContentItem> items) {
  final map = <String, List<ContentItem>>{};
  for (final it in items) {
    final key = it.title.trim();
    map.putIfAbsent(key, () => []).add(it);
  }
  return map;
}
