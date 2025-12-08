import 'content_item.dart';

class SeriesDetails {
  final Map<String, List<ContentItem>> seasons;

  SeriesDetails({required this.seasons});

  factory SeriesDetails.fromJson(Map<String, dynamic> json) {
    Map<String, List<ContentItem>> parsedSeasons = {};
    
    if (json['seasons'] != null) {
      json['seasons'].forEach((key, value) {
        var list = value as List;
        parsedSeasons[key] = list.map((i) => ContentItem.fromJson(i)).toList();
      });
    }
    return SeriesDetails(seasons: parsedSeasons);
  }
}