class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final double? voteAverage;
  final String? releaseDate;
  final List<Genre> genres;

  Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.voteAverage,
    this.releaseDate,
    this.genres = const [],
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['original_title'] as String? ?? 'Без названия',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      releaseDate: json['release_date'] as String?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  String? get posterUrl {
    if (posterPath == null) return null;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String? get releaseYear {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    try {
      return releaseDate!.substring(0, 4);
    } catch (e) {
      return null;
    }
  }
}

class Genre {
  final int id;
  final String name;

  Genre({
    required this.id,
    required this.name,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
