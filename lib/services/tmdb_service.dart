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
      
      // Случайно выбираем между фильмами и сериалами
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
          
          // Чередуем между фильмами и сериалами
          if (attempt >= 3) {
            currentIsTvShow = !isTvShow;
          }
          
          switch (attempt % 3) {
            case 0:
              // Популярные
              final randomPage = random.nextInt(100) + 1;
              if (currentIsTvShow) {
                url = '$baseUrl/tv/popular?api_key=$apiKey&language=ru-RU&page=$randomPage';
              } else {
                url = '$baseUrl/movie/popular?api_key=$apiKey&language=ru-RU&page=$randomPage';
              }
              break;
            case 1:
              // Топ рейтинговые
              final randomPage = random.nextInt(50) + 1;
              if (currentIsTvShow) {
                url = '$baseUrl/tv/top_rated?api_key=$apiKey&language=ru-RU&page=$randomPage';
              } else {
                url = '$baseUrl/movie/top_rated?api_key=$apiKey&language=ru-RU&page=$randomPage';
              }
              break;
            case 2:
              // Новые (discover)
              final randomPage = random.nextInt(50) + 1;
              final year = DateTime.now().year - random.nextInt(5);
              if (currentIsTvShow) {
                url = '$baseUrl/discover/tv?api_key=$apiKey&language=ru-RU&page=$randomPage&sort_by=popularity.desc&first_air_date_year=$year';
              } else {
                url = '$baseUrl/discover/movie?api_key=$apiKey&language=ru-RU&page=$randomPage&sort_by=popularity.desc&year=$year';
              }
              break;
            default:
              url = '$baseUrl/movie/popular?api_key=$apiKey&language=ru-RU&page=1';
              currentIsTvShow = false;
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
              ? '$baseUrl/tv/$itemId?api_key=$apiKey&language=ru-RU'
              : '$baseUrl/movie/$itemId?api_key=$apiKey&language=ru-RU';
          
          final detailsResponse = await http.get(Uri.parse(detailsUrl));

          if (detailsResponse.statusCode == 200) {
            final Map<String, dynamic> itemJson = jsonDecode(detailsResponse.body);
            return Movie.fromJson(itemJson, isTvShow: currentIsTvShow);
          }

          // Если детали не получены, возвращаем базовую информацию
          return Movie.fromJson(randomItem, isTvShow: currentIsTvShow);
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
}
