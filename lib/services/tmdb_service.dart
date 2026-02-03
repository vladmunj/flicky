import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movie.dart';

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

  Future<Movie?> getRandomMovie({
    Set<int>? excludeIds,
    String languageCode = 'en',
    int? year,
    List<int>? genreIds,
    double? minRating,
  }) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    try {
      final random = Random();
      final tmdbLang = languageCode.toLowerCase() == 'ru' ? 'ru-RU' : 'en-US';
      final hasFilters =
          year != null || (genreIds != null && genreIds.isNotEmpty) || minRating != null;
      
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
}
