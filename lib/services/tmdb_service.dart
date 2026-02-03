import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movie.dart';

class TMDbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  String? get apiKey => dotenv.env['TMDB_API_KEY'];

  Future<Movie?> getRandomMovie() async {
    if (apiKey == null || apiKey!.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('TMDB_API_KEY не установлен в .env файле');
    }

    try {
      // Получаем список популярных фильмов
      final popularResponse = await http.get(
        Uri.parse('$baseUrl/movie/popular?api_key=$apiKey&language=ru-RU&page=1'),
      );

      if (popularResponse.statusCode != 200) {
        throw Exception('Ошибка при получении фильмов: ${popularResponse.statusCode}');
      }

      // Парсим JSON ответ
      final Map<String, dynamic> jsonData = jsonDecode(popularResponse.body);
      final List<dynamic> results = jsonData['results'] as List<dynamic>;

      if (results.isEmpty) {
        return null;
      }

      // Выбираем случайный фильм
      final random = Random();
      final randomMovie = results[random.nextInt(results.length)] as Map<String, dynamic>;
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
      throw Exception('Ошибка при получении фильма: $e');
    }
  }
}
