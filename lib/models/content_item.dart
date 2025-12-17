class ContentItem {
  final String title;
  final String url;
  final String image;
  final String group;
  final String type; // 'movie', 'series', 'channel'
  final bool isSeries;
  final String id;
  final double rating;
  final String year;
  String quality; // sd, hd, fhd, uhd4k
  String audioType; // 'dub', 'leg', 'multi'

  ContentItem({
    required this.title,
    required this.url,
    required this.image,
    required this.group,
    this.type = 'movie',
    this.isSeries = false,
    this.id = '',
    this.rating = 0.0,
    this.year = "2024",
    this.quality = 'sd',
    this.audioType = '',
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      title: json['title'] ?? "Sem Título",
      url: json['url'] ?? "",
      image: json['logo'] ?? "",
      group: json['group'] ?? "Geral",
      type: json['type'] ?? "movie",
      isSeries: json['isSeries'] ?? false,
      id: json['id'] ?? "",
      rating: 8.5,
      year: "2024",
      quality: json['quality'] ?? 'sd',
      audioType: json['audioType'] ?? '',
    );
  }
}