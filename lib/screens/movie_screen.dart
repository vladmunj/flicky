import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  final TMDbService _tmdbService = TMDbService();
  Movie? _currentMovie;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRandomMovie();
  }

  Future<void> _loadRandomMovie() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movie = await _tmdbService.getRandomMovie();
      setState(() {
        _currentMovie = movie;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openStreamingService(String service, String movieTitle) async {
    String url;
    
    switch (service.toLowerCase()) {
      case 'netflix':
        url = 'https://www.netflix.com/search?q=${Uri.encodeComponent(movieTitle)}';
        break;
      case 'amazon':
        url = 'https://www.amazon.com/s?k=${Uri.encodeComponent(movieTitle)}&i=prime-instant-video';
        break;
      case 'apple':
        url = 'https://tv.apple.com/search?term=${Uri.encodeComponent(movieTitle)}';
        break;
      case 'google':
        url = 'https://play.google.com/store/search?q=${Uri.encodeComponent(movieTitle)}&c=movies';
        break;
      default:
        return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть $service')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 Flicky'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadRandomMovie,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _currentMovie == null
                  ? const Center(child: Text('Фильм не найден'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Постер
                          if (_currentMovie!.posterUrl != null)
                            Container(
                              height: 500,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                              ),
                              child: CachedNetworkImage(
                                imageUrl: _currentMovie!.posterUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => const Center(
                                  child: Icon(Icons.error, size: 64),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 500,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.movie, size: 100, color: Colors.grey),
                              ),
                            ),
                          
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Название
                                Text(
                                  _currentMovie!.title,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Рейтинг и год
                                Row(
                                  children: [
                                    if (_currentMovie!.voteAverage != null) ...[
                                      const Icon(Icons.star, color: Colors.amber, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentMovie!.voteAverage!.toStringAsFixed(1),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    if (_currentMovie!.releaseYear != null)
                                      Text(
                                        _currentMovie!.releaseYear!,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Жанры
                                if (_currentMovie!.genres.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _currentMovie!.genres.map((genre) {
                                      return Chip(
                                        label: Text(genre.name),
                                        backgroundColor: Colors.blue[50],
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                
                                // Описание
                                if (_currentMovie!.overview != null && _currentMovie!.overview!.isNotEmpty) ...[
                                  Text(
                                    'Описание',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentMovie!.overview!,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                
                                // Кнопки стриминговых сервисов
                                Text(
                                  'Смотреть на:',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Netflix
                                _StreamingButton(
                                  icon: Icons.play_circle_outline,
                                  label: 'Netflix',
                                  color: Colors.red,
                                  onTap: () => _openStreamingService('netflix', _currentMovie!.title),
                                ),
                                const SizedBox(height: 8),
                                
                                // Amazon Prime Video
                                _StreamingButton(
                                  icon: Icons.play_circle_outline,
                                  label: 'Amazon Prime Video',
                                  color: Colors.blue,
                                  onTap: () => _openStreamingService('amazon', _currentMovie!.title),
                                ),
                                const SizedBox(height: 8),
                                
                                // Apple TV
                                _StreamingButton(
                                  icon: Icons.play_circle_outline,
                                  label: 'Apple TV',
                                  color: Colors.black,
                                  onTap: () => _openStreamingService('apple', _currentMovie!.title),
                                ),
                                const SizedBox(height: 8),
                                
                                // Google Play Movies
                                _StreamingButton(
                                  icon: Icons.play_circle_outline,
                                  label: 'Google Play Movies',
                                  color: Colors.green,
                                  onTap: () => _openStreamingService('google', _currentMovie!.title),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Кнопка "Новый фильм"
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _loadRandomMovie,
                                    icon: const Icon(Icons.casino),
                                    label: const Text('🎲 Случайный фильм'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      textStyle: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StreamingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StreamingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: color),
        ),
      ),
    );
  }
}
