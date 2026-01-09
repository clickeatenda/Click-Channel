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
  final String description; // Resumo/sinopse
  final String genre; // Gênero
  final double popularity; // Popularidade (para ordenação)
  final String? releaseDate; // Data de lançamento (para ordenação)

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
    this.description = '',
    this.genre = '',
    this.popularity = 0.0,
    this.releaseDate,
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
      rating: (json['rating'] ?? 0.0).toDouble(),
      year: json['year']?.toString() ?? "2024",
      quality: json['quality'] ?? 'sd',
      audioType: json['audioType'] ?? '',
      description: json['description'] ?? json['plot'] ?? '',
      genre: json['genre'] ?? '',
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      releaseDate: json['releaseDate'] ?? json['release_date'],
    );
  }

  /// Enriquece o item com dados do TMDB
  ContentItem enrichWithTmdb({
    double? rating,
    String? description,
    String? genre,
    double? popularity,
    String? releaseDate,
  }) {
    // CRÍTICO: Se rating foi fornecido (mesmo que seja 0), usa ele
    // Isso garante que ratings do TMDB sejam aplicados corretamente
    final finalRating = rating ?? this.rating;
    
    return ContentItem(
      title: title,
      url: url,
      image: image,
      group: group,
      type: type,
      isSeries: isSeries,
      id: id,
      rating: finalRating,
      year: year,
      quality: quality,
      audioType: audioType,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      popularity: popularity ?? this.popularity,
      releaseDate: releaseDate ?? this.releaseDate,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'logo': image, // Compatível com fromJson
      'group': group,
      'type': type,
      'isSeries': isSeries,
      'id': id,
      'rating': rating,
      'year': year,
      'quality': quality,
      'audioType': audioType,
      'description': description,
      'genre': genre,
      'popularity': popularity,
      'releaseDate': releaseDate,
    };
  }
}