import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movie.dart';

class TMDbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  String? get apiKey => dotenv.env['TMDB_API_KEY'];

  Future<Movie?> getRandomMovie({Set<int>? excludeIds}) async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    try {
      final random = Random();
      
      // Пробуем несколько подходов для большей случайности
      // 1. Популярные фильмы со случайной страницы
      // 2. Топ рейтинговые фильмы
      // 3. Новые фильмы
      
      int attempt = 0;
      const maxAttempts = 3;
      
      while (attempt < maxAttempts) {
        try {
          String url;
          
          switch (attempt) {
            case 0:
              // Популярные фильмы со случайной страницы (1-100)
              final randomPage = random.nextInt(100) + 1;
              url = '$baseUrl/movie/popular?api_key=$apiKey&language=ru-RU&page=$randomPage';
              break;
            case 1:
              // Топ рейтинговые фильмы со случайной страницы
              final randomPage = random.nextInt(50) + 1;
              url = '$baseUrl/movie/top_rated?api_key=$apiKey&language=ru-RU&page=$randomPage';
              break;
            case 2:
              // Новые фильмы (discover с разными параметрами)
              final randomPage = random.nextInt(50) + 1;
              final year = DateTime.now().year - random.nextInt(5); // Последние 5 лет
              url = '$baseUrl/discover/movie?api_key=$apiKey&language=ru-RU&page=$randomPage&sort_by=popularity.desc&year=$year';
              break;
            default:
              url = '$baseUrl/movie/popular?api_key=$apiKey&language=ru-RU&page=1';
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

          // Фильтруем исключенные фильмы
          List<dynamic> availableMovies = results;
          if (excludeIds != null && excludeIds.isNotEmpty) {
            availableMovies = results.where((movie) {
              final id = (movie as Map<String, dynamic>)['id'] as int;
              return !excludeIds.contains(id);
            }).toList();
          }

          // Если после фильтрации не осталось фильмов, используем все
          if (availableMovies.isEmpty) {
            availableMovies = results;
          }

          // Выбираем случайный фильм
          final randomMovie = availableMovies[random.nextInt(availableMovies.length)] as Map<String, dynamic>;
          final movieId = randomMovie['id'] as int;

          // Получаем детальную информацию о фильме
          final detailsResponse = await http.get(
            Uri.parse('$baseUrl/movie/$movieId?api_key=$apiKey&language=ru-RU'),
          );

          if (detailsResponse.statusCode == 200) {
            final Map<String, dynamic> movieJson = jsonDecode(detailsResponse.body);
            return Movie.fromJson(movieJson);
          }

          // Если детали не получены, возвращаем базовую информацию
          return Movie.fromJson(randomMovie);
        } catch (e) {
          attempt++;
          if (attempt >= maxAttempts) {
            throw Exception('Ошибка при получении фильма: $e');
          }
        }
      }
      
      return null;
    } catch (e) {
      throw Exception('Ошибка при получении фильма: $e');
    }
  }
}
