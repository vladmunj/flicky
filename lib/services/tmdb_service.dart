import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movie.dart';

class PagedMoviesResult {
  final List<Movie> items;
  final bool hasMore;
  final int nextPage;

  const PagedMoviesResult({
    required this.items,
    required this.hasMore,
    required this.nextPage,
  });
}

class TMDbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  String? get apiKey => dotenv.env['TMDB_API_KEY'];

  Future<List<Genre>> fetchMovieGenres({String languageCode = 'en'}) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
    final url = '$baseUrl/genre/movie/list?api_key=$apiKey&language=$tmdbLang';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Ошибка при получении жанров: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> results = jsonData['genres'] as List<dynamic>;
    return results.map((e) => Genre.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Country>> fetchCountries() async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    final url = '$baseUrl/configuration/countries?api_key=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Ошибка при получении стран: ${response.statusCode}');
    }

    final List<dynamic> jsonData = jsonDecode(response.body) as List<dynamic>;
    return jsonData.map((e) => Country.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<PagedMoviesResult> discoverMoviesAndTv({
    required String languageCode,
    int? year,
    List<int>? genreIds,
    double? minRating,
    String? countryCode,
    int page = 1,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';

    String buildCommonParams({required bool isTv}) {
      final buffer = StringBuffer();
      if (genreIds != null && genreIds.isNotEmpty) {
        buffer.write('&with_genres=${genreIds.join(',')}');
      }
      if (year != null) {
        if (isTv) {
          buffer.write('&first_air_date_year=$year');
        } else {
          buffer.write('&primary_release_year=$year');
        }
      }
      if (minRating != null) {
        buffer.write('&vote_average.gte=${minRating.toStringAsFixed(1)}&vote_count.gte=50');
      }
      if (countryCode != null && countryCode.isNotEmpty) {
        buffer.write('&with_origin_country=$countryCode');
      }
      return buffer.toString();
    }

    final movieUrl =
        '$baseUrl/discover/movie?api_key=$apiKey&language=$tmdbLang&page=$page&sort_by=popularity.desc${buildCommonParams(isTv: false)}';
    final tvUrl =
        '$baseUrl/discover/tv?api_key=$apiKey&language=$tmdbLang&page=$page&sort_by=popularity.desc${buildCommonParams(isTv: true)}';

    final responses = await Future.wait([
      http.get(Uri.parse(movieUrl)),
      http.get(Uri.parse(tvUrl)),
    ]);

    final List<Movie> items = [];
    bool hasMore = false;

    void handleResponse(http.Response response, {required bool isTvShow}) {
      if (response.statusCode != 200) return;
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      final List<dynamic> results = jsonData['results'] as List<dynamic>;
      final int totalPages = jsonData['total_pages'] as int? ?? 1;

      if (page < totalPages) {
        hasMore = true;
      }

      for (final item in results) {
        final map = item as Map<String, dynamic>;
        items.add(Movie.fromJson(map, isTvShow: isTvShow));
      }
    }

    handleResponse(responses[0], isTvShow: false);
    handleResponse(responses[1], isTvShow: true);

    // Сортируем по рейтингу (по убыванию), если рейтинг есть
    items.sort((a, b) {
      final ar = a.voteAverage ?? 0;
      final br = b.voteAverage ?? 0;
      return br.compareTo(ar);
    });

    return PagedMoviesResult(
      items: items,
      hasMore: hasMore,
      nextPage: page + 1,
    );
  }

  Future<PagedMoviesResult> searchMoviesAndTv({
    required String languageCode,
    required String query,
    int page = 1,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
    final encodedQuery = Uri.encodeQueryComponent(query);

    final movieUrl =
        '$baseUrl/search/movie?api_key=$apiKey&language=$tmdbLang&page=$page&include_adult=false&query=$encodedQuery';
    final tvUrl =
        '$baseUrl/search/tv?api_key=$apiKey&language=$tmdbLang&page=$page&include_adult=false&query=$encodedQuery';

    final responses = await Future.wait([
      http.get(Uri.parse(movieUrl)),
      http.get(Uri.parse(tvUrl)),
    ]);

    final List<Movie> items = [];
    bool hasMore = false;

    void handleResponse(http.Response response, {required bool isTvShow}) {
      if (response.statusCode != 200) return;
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      final List<dynamic> results = jsonData['results'] as List<dynamic>;
      final int totalPages = jsonData['total_pages'] as int? ?? 1;

      if (page < totalPages) {
        hasMore = true;
      }

      for (final item in results) {
        final map = item as Map<String, dynamic>;
        items.add(Movie.fromJson(map, isTvShow: isTvShow));
      }
    }

    handleResponse(responses[0], isTvShow: false);
    handleResponse(responses[1], isTvShow: true);

    // Сортируем по популярности (если есть)
    items.sort((a, b) {
      final ar = a.voteAverage ?? 0;
      final br = b.voteAverage ?? 0;
      return br.compareTo(ar);
    });

    return PagedMoviesResult(
      items: items,
      hasMore: hasMore,
      nextPage: page + 1,
    );
  }

  Future<Movie?> getRandomMovie({
    Set<int>? excludeIds,
    String languageCode = 'en',
    int? year,
    List<int>? genreIds,
    double? minRating,
    String? countryCode,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    try {
      final random = Random();
      final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
      final hasFilters =
          year != null || (genreIds != null && genreIds.isNotEmpty) || minRating != null || (countryCode != null && countryCode.isNotEmpty);
      
      // Случайно выбираем между фильмами и сериалами (для фильтрованных тоже оставим шанс сериала)
      final isTvShow = random.nextBool();
      
      // Пробуем несколько подходов для большей случайности
      // Для фильмов: популярные, топ рейтинговые, новые
      // Для сериалов: популярные, топ рейтинговые, новые
      
      int attempt = 0;
      const maxAttempts = 6; // Увеличиваем количество попыток
      
      while (attempt < maxAttempts) {
        try {
          String url;
          bool currentIsTvShow = isTvShow;
          
          // Если есть фильтры, используем только discover с нужными параметрами
          if (hasFilters) {
            final randomPage = random.nextInt(50) + 1;
            final buffer = StringBuffer();
            if (genreIds != null && genreIds.isNotEmpty) {
              buffer.write('&with_genres=${genreIds.join(',')}');
            }
            if (year != null) {
              if (currentIsTvShow) {
                buffer.write('&first_air_date_year=$year');
              } else {
                // Для фильмов используем primary_release_year, он точнее работает в discover
                buffer.write('&primary_release_year=$year');
              }
            }
            if (minRating != null) {
              // Немного отсеиваем редкие фильмы с малым количеством голосов
              buffer.write('&vote_average.gte=${minRating.toStringAsFixed(1)}&vote_count.gte=50');
            }
            if (countryCode != null && countryCode.isNotEmpty) {
              buffer.write('&with_origin_country=$countryCode');
            }
            if (currentIsTvShow) {
              url =
                  '$baseUrl/discover/tv?api_key=$apiKey&language=$tmdbLang&page=$randomPage&sort_by=popularity.desc${buffer.toString()}';
            } else {
              url =
                  '$baseUrl/discover/movie?api_key=$apiKey&language=$tmdbLang&page=$randomPage&sort_by=popularity.desc${buffer.toString()}';
            }
          } else {
            // Без фильтров используем старую стратегию
            // Чередуем между фильмами и сериалами
            if (attempt >= 3) {
              currentIsTvShow = !isTvShow;
            }

            switch (attempt % 3) {
              case 0:
                // Популярные
                final randomPage = random.nextInt(100) + 1;
                if (currentIsTvShow) {
                  url = '$baseUrl/tv/popular?api_key=$apiKey&language=$tmdbLang&page=$randomPage';
                } else {
                  url = '$baseUrl/movie/popular?api_key=$apiKey&language=$tmdbLang&page=$randomPage';
                }
                break;
              case 1:
                // Топ рейтинговые
                final randomPage = random.nextInt(50) + 1;
                if (currentIsTvShow) {
                  url = '$baseUrl/tv/top_rated?api_key=$apiKey&language=$tmdbLang&page=$randomPage';
                } else {
                  url = '$baseUrl/movie/top_rated?api_key=$apiKey&language=$tmdbLang&page=$randomPage';
                }
                break;
              case 2:
                // Новые (discover)
                final randomPage = random.nextInt(50) + 1;
                final randomYear = DateTime.now().year - random.nextInt(5);
                if (currentIsTvShow) {
                  url =
                      '$baseUrl/discover/tv?api_key=$apiKey&language=$tmdbLang&page=$randomPage&sort_by=popularity.desc&first_air_date_year=$randomYear';
                } else {
                  url =
                      '$baseUrl/discover/movie?api_key=$apiKey&language=$tmdbLang&page=$randomPage&sort_by=popularity.desc&year=$randomYear';
                }
                break;
              default:
                url = '$baseUrl/movie/popular?api_key=$apiKey&language=$tmdbLang&page=1';
                currentIsTvShow = false;
            }
          }
          
          final response = await http.get(Uri.parse(url));
          
          if (response.statusCode != 200) {
            attempt++;
            continue;
          }

          final Map<String, dynamic> jsonData = jsonDecode(response.body);
          final List<dynamic> results = jsonData['results'] as List<dynamic>;

          if (results.isEmpty) {
            attempt++;
            continue;
          }

          // Фильтруем исключенные фильмы/сериалы
          List<dynamic> availableItems = results;
          if (excludeIds != null && excludeIds.isNotEmpty) {
            availableItems = results.where((item) {
              final id = (item as Map<String, dynamic>)['id'] as int;
              return !excludeIds.contains(id);
            }).toList();
          }

          // Если после фильтрации не осталось, используем все
          if (availableItems.isEmpty) {
            availableItems = results;
          }

          // Выбираем случайный элемент
          final randomItem = availableItems[random.nextInt(availableItems.length)] as Map<String, dynamic>;
          final itemId = randomItem['id'] as int;

          // Получаем детальную информацию
          final detailsUrl = currentIsTvShow
              ? '$baseUrl/tv/$itemId?api_key=$apiKey&language=$tmdbLang'
              : '$baseUrl/movie/$itemId?api_key=$apiKey&language=$tmdbLang';
          
          final detailsResponse = await http.get(Uri.parse(detailsUrl));

          if (detailsResponse.statusCode == 200) {
            final Map<String, dynamic> itemJson = jsonDecode(detailsResponse.body);
            final movie = Movie.fromJson(itemJson, isTvShow: currentIsTvShow);

            // Дополнительная защита: проверяем год и рейтинг уже по детальному ответу
            if (hasFilters) {
              if (year != null) {
                final yearStr = movie.releaseYear;
                final parsedYear = yearStr != null ? int.tryParse(yearStr) : null;
                if (parsedYear != null && parsedYear != year) {
                  attempt++;
                  continue;
                }
              }
              if (minRating != null) {
                final rating = movie.voteAverage;
                if (rating != null && rating < minRating) {
                  attempt++;
                  continue;
                }
              }
            }
            
            // Получаем трейлер, если доступен
            final trailerKey = await _getTrailerKey(itemId, currentIsTvShow, tmdbLang: tmdbLang);
            if (trailerKey != null) {
              return Movie(
                id: movie.id,
                title: movie.title,
                overview: movie.overview,
                posterPath: movie.posterPath,
                voteAverage: movie.voteAverage,
                releaseDate: movie.releaseDate,
                genres: movie.genres,
                isTvShow: movie.isTvShow,
                trailerKey: trailerKey,
              );
            }
            
            return movie;
          }

          // Если детали не получены, возвращаем базовую информацию
          final movie = Movie.fromJson(randomItem, isTvShow: currentIsTvShow);
          if (hasFilters) {
            if (year != null) {
              final yearStr = movie.releaseYear;
              final parsedYear = yearStr != null ? int.tryParse(yearStr) : null;
              if (parsedYear != null && parsedYear != year) {
                attempt++;
                continue;
              }
            }
            if (minRating != null) {
              final rating = movie.voteAverage;
              if (rating != null && rating < minRating) {
                attempt++;
                continue;
              }
            }
          }
          return movie;
        } catch (e) {
          attempt++;
          if (attempt >= maxAttempts) {
            throw Exception('Ошибка при получении контента: $e');
          }
        }
      }
      
      return null;
    } catch (e) {
      throw Exception('Ошибка при получении контента: $e');
    }
  }

  Future<String?> _getTrailerKey(int id, bool isTvShow, {required String tmdbLang}) async {
    try {
      Future<http.Response> fetch(String lang) {
        final videosUrl = isTvShow
            ? '$baseUrl/tv/$id/videos?api_key=$apiKey&language=$lang'
            : '$baseUrl/movie/$id/videos?api_key=$apiKey&language=$lang';
        return http.get(Uri.parse(videosUrl));
      }

      // Сначала пробуем на выбранном языке, потом fallback на en-US (часто больше результатов)
      var response = await fetch(tmdbLang);
      if (response.statusCode != 200 || (jsonDecode(response.body)['results'] as List).isEmpty) {
        response = await fetch('en-US');
      }
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic> results = jsonData['results'] as List<dynamic>;
        
        // Ищем трейлер (type: "Trailer" и site: "YouTube")
        for (var video in results) {
          final videoData = video as Map<String, dynamic>;
          final type = videoData['type'] as String?;
          final site = videoData['site'] as String?;
          final key = videoData['key'] as String?;
          
          if (type == 'Trailer' && site == 'YouTube' && key != null) {
            return key;
          }
        }
        
        // Если не нашли трейлер, ищем любой YouTube видео
        for (var video in results) {
          final videoData = video as Map<String, dynamic>;
          final site = videoData['site'] as String?;
          final key = videoData['key'] as String?;
          
          if (site == 'YouTube' && key != null) {
            return key;
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки при получении трейлера
    }
    
    return null;
  }

  // Curated lists
  Future<List<Movie>> getCuratedNew({required String languageCode}) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }
    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
    final now = DateTime.now();
    // Период: с начала предыдущего года до конца предыдущего месяца
    final fromDate = DateTime(now.year - 1, 1, 1);
    final toDate = DateTime(now.year, now.month, 0); // последний день предыдущего месяца
    String formatDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final commonRange =
        '&vote_average.gte=7.0&vote_count.gte=100'
        '&first_air_date.gte=${formatDate(fromDate)}&first_air_date.lte=${formatDate(toDate)}';

    final movieUrl =
        '$baseUrl/discover/movie?api_key=$apiKey&language=$tmdbLang'
        '&sort_by=primary_release_date.desc'
        '&primary_release_date.gte=${formatDate(fromDate)}'
        '&primary_release_date.lte=${formatDate(toDate)}'
        '&vote_average.gte=7.0&vote_count.gte=100'
        '&page=1';

    final tvUrl =
        '$baseUrl/discover/tv?api_key=$apiKey&language=$tmdbLang'
        '&sort_by=first_air_date.desc'
        '$commonRange'
        '&page=1';

    final responses = await Future.wait([
      http.get(Uri.parse(movieUrl)),
      http.get(Uri.parse(tvUrl)),
    ]);

    final List<Movie> items = [];

    void handleResponse(http.Response response, {required bool isTvShow}) {
      if (response.statusCode != 200) return;
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      final List<dynamic> results = jsonData['results'] as List<dynamic>;
      for (final item in results) {
        items.add(Movie.fromJson(item as Map<String, dynamic>, isTvShow: isTvShow));
      }
    }

    handleResponse(responses[0], isTvShow: false);
    handleResponse(responses[1], isTvShow: true);

    // Сортируем по дате релиза (по убыванию), fallback по рейтингу
    items.sort((a, b) {
      final ad = a.releaseDate ?? '';
      final bd = b.releaseDate ?? '';
      if (ad.isNotEmpty && bd.isNotEmpty && ad != bd) {
        return bd.compareTo(ad);
      }
      final ar = a.voteAverage ?? 0;
      final br = b.voteAverage ?? 0;
      return br.compareTo(ar);
    });

    return items.take(10).toList();
  }

  Future<List<Movie>> getCuratedTopRatedMovies({required String languageCode}) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }
    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';

    final url =
        '$baseUrl/discover/movie?api_key=$apiKey&language=$tmdbLang&sort_by=vote_average.desc&vote_count.gte=500&page=1';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> results = jsonData['results'] as List<dynamic>;
    return results
        .map((e) => Movie.fromJson(e as Map<String, dynamic>, isTvShow: false))
        .take(10)
        .toList();
  }

  Future<List<Movie>> getCuratedTopRatedTv({required String languageCode}) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }
    final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
    final currentYear = DateTime.now().year;
    final fromYear = currentYear - 5;

    final url =
        '$baseUrl/discover/tv?api_key=$apiKey&language=$tmdbLang&sort_by=vote_average.desc&first_air_date.gte=$fromYear-01-01&vote_count.gte=200&page=1';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> results = jsonData['results'] as List<dynamic>;
    return results
        .map((e) => Movie.fromJson(e as Map<String, dynamic>, isTvShow: true))
        .take(10)
        .toList();
  }
}
