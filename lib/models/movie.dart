class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final double? voteAverage;
  final String? releaseDate;
  final List<Genre> genres;
  final bool isTvShow; // Флаг для сериалов
  final String? trailerKey; // Ключ трейлера на YouTube

  Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.voteAverage,
    this.releaseDate,
    this.genres = const [],
    this.isTvShow = false,
    this.trailerKey,
  });

  factory Movie.fromJson(Map<String, dynamic> json, {bool isTvShow = false}) {
    return Movie(
      id: json['id'] as int,
      title: isTvShow 
          ? (json['name'] as String? ?? json['original_name'] as String? ?? 'Без названия')
          : (json['title'] as String? ?? json['original_title'] as String? ?? 'Без названия'),
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      releaseDate: isTvShow 
          ? (json['first_air_date'] as String?)
          : (json['release_date'] as String?),
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
          .toList() ?? [],
      isTvShow: isTvShow,
      trailerKey: null, // Будет установлено отдельно
    );
  }

  String? get trailerUrl {
    if (trailerKey == null) return null;
    return 'https://www.youtube.com/watch?v=$trailerKey';
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

class Country {
  final String code;
  final String name;

  Country({
    required this.code,
    required this.name,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['iso_3166_1'] as String,
      name: json['english_name'] as String,
    );
  }
}

class CastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int? order;
  final double? popularity;
  final String? knownForDepartment;

  const CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    this.order,
    this.popularity,
    this.knownForDepartment,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      character: json['character'] as String?,
      profilePath: json['profile_path'] as String?,
      order: json['order'] as int?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      knownForDepartment: json['known_for_department'] as String?,
    );
  }

  String? get profileUrl {
    if (profilePath == null) return null;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }
}
