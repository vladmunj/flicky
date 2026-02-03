import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../l10n/app_localizations.dart';
import 'filter_screen.dart';

class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> with SingleTickerProviderStateMixin {
  final TMDbService _tmdbService = TMDbService();
  Movie? _currentMovie;
  bool _isLoading = false;
  String? _errorMessage;
  int _movieKey = 0; // Ключ для анимации
  double _swipeOffset = 0.0;
  String? _swipeDirection; // Направление свайпа для анимации
  double _dragStartX = 0.0;
  final Set<int> _shownMovieIds = {}; // Кэш показанных фильмов
  int? _filterYear;
  List<int> _filterGenreIds = [];
  double? _filterMinRating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRandomMovie();
    });
  }

  Future<void> _loadRandomMovie() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Если показано много фильмов, очищаем кэш для разнообразия
      if (_shownMovieIds.length > 50) {
        _shownMovieIds.clear();
      }

      final lang = Localizations.localeOf(context).languageCode;
      final movie = await _tmdbService.getRandomMovie(
        excludeIds: _shownMovieIds,
        languageCode: lang,
        year: _filterYear,
        genreIds: _filterGenreIds.isEmpty ? null : _filterGenreIds,
        minRating: _filterMinRating,
      );
      if (movie != null) {
        setState(() {
          _currentMovie = movie;
          _shownMovieIds.add(movie.id); // Добавляем в кэш
          _isLoading = false;
        });
      } else {
        setState(() {
          final hasFilters = _filterYear != null || _filterGenreIds.isNotEmpty;
          _errorMessage = hasFilters ? context.l10n.noResultsForFilters : context.l10n.loadFailed;
          _isLoading = false;
        });
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Улучшаем сообщение об ошибке
      if (errorMsg.contains('TMDB_API_KEY')) {
        errorMsg = context.l10n.apiKeyMissing;
      } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
        errorMsg = context.l10n.apiKeyInvalid;
      } else if (errorMsg.contains('network') || errorMsg.contains('Internet')) {
        errorMsg = context.l10n.networkIssue;
      } else {
        errorMsg = context.l10n.loadFailed;
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      
      // Показываем уведомление об ошибке
      _showErrorSnackBar(errorMsg);
    }
  }

  Future<void> _openStreamingService(String service, String movieTitle) async {
    String url;
    String serviceName;
    
    switch (service.toLowerCase()) {
      case 'netflix':
        url = 'https://www.netflix.com/search?q=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Netflix';
        break;
      case 'amazon':
        url = 'https://www.primevideo.com/search/ref=atv_sr?phrase=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Amazon Prime Video';
        break;
      case 'apple':
        url = 'https://tv.apple.com/search?term=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Apple TV';
        break;
      case 'disney':
        url = 'https://www.disneyplus.com/search/${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Disney+';
        break;
      case 'hbomax':
        url = 'https://play.max.com/search?q=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'HBO Max';
        break;
      case 'amediateka':
        final search = '$movieTitle site:amediateka.ru';
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(search)}';
        serviceName = 'Amediateka';
        break;
      case 'ivi':
        url = 'https://www.ivi.ru/search?ivi_search=${Uri.encodeComponent(movieTitle)}';
        serviceName = context.l10n.iviLabel;
        break;
      case 'kinopoisk':
        url = 'https://www.kinopoisk.ru/index.php?kp_query=${Uri.encodeComponent(movieTitle)}';
        serviceName = context.l10n.kinopoiskLabel;
        break;
      default:
        return;
    }

    debugPrint('🔗 [Flicky] Попытка открыть $serviceName');
    debugPrint('🔗 [Flicky] URL: $url');
    debugPrint('🔗 [Flicky] Фильм: $movieTitle');


    final uri = Uri.parse(url);
    
    // На Android canLaunchUrl может быть ненадежным, поэтому проверяем, но не блокируем
    final canLaunch = await canLaunchUrl(uri);
    debugPrint('🔗 [Flicky] canLaunchUrl: $canLaunch');
    
    if (!canLaunch) {
      debugPrint('⚠️ [Flicky] canLaunchUrl вернул false, но продолжаем попытку открытия (может быть ложное срабатывание на Android)');
    }

    // Сначала пытаемся открыть в приложении
    bool openedInApp = false;
    debugPrint('🔗 [Flicky] Попытка открыть в приложении (externalNonBrowserApplication)...');
    try {
      openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      debugPrint('🔗 [Flicky] externalNonBrowserApplication результат: $openedInApp');
    } catch (e) {
      debugPrint('❌ [Flicky] Ошибка при открытии в приложении: $e');
      debugPrint('❌ [Flicky] Тип ошибки: ${e.runtimeType}');
    }

    // Если не открылось в приложении, открываем в браузере
    if (!openedInApp) {
      debugPrint('🔗 [Flicky] Приложение не открылось, пробуем браузер...');
      try {
        debugPrint('🔗 [Flicky] Попытка открыть в браузере (externalApplication)...');
        final openedInBrowser = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('🔗 [Flicky] externalApplication результат: $openedInBrowser');
        
        if (!openedInBrowser) {
          debugPrint('❌ [Flicky] externalApplication вернул false, пробуем inAppWebView...');
          // Если externalApplication не сработал, пробуем inAppWebView (встроенный браузер)
          try {
            final openedWebView = await launchUrl(uri, mode: LaunchMode.inAppWebView);
            debugPrint('🔗 [Flicky] inAppWebView результат: $openedWebView');
            if (!openedWebView) {
              debugPrint('❌ [Flicky] inAppWebView вернул false, пробуем platformDefault...');
              // Если inAppWebView не сработал, пробуем platformDefault
              try {
                final openedPlatform = await launchUrl(uri, mode: LaunchMode.platformDefault);
                debugPrint('🔗 [Flicky] platformDefault результат: $openedPlatform');
                if (!openedPlatform) {
                  debugPrint('❌ [Flicky] Все попытки открытия вернули false');
                  _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
                } else {
                  debugPrint('✅ [Flicky] Успешно открыто через platformDefault');
                }
              } catch (e) {
                debugPrint('❌ [Flicky] Ошибка при platformDefault: $e');
                debugPrint('❌ [Flicky] Тип ошибки: ${e.runtimeType}');
                _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
              }
            } else {
              debugPrint('✅ [Flicky] Успешно открыто через inAppWebView');
            }
          } catch (e) {
            debugPrint('❌ [Flicky] Ошибка при inAppWebView: $e');
            debugPrint('❌ [Flicky] Тип ошибки: ${e.runtimeType}');
            // Пробуем platformDefault как последний вариант
            try {
              final openedPlatform = await launchUrl(uri, mode: LaunchMode.platformDefault);
              debugPrint('🔗 [Flicky] platformDefault (fallback) результат: $openedPlatform');
              if (!openedPlatform) {
                _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
              }
            } catch (e2) {
              debugPrint('❌ [Flicky] Ошибка при platformDefault (fallback): $e2');
              _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
            }
          }
        } else {
          debugPrint('✅ [Flicky] Успешно открыто в браузере через externalApplication');
        }
      } catch (e) {
        debugPrint('❌ [Flicky] Ошибка при открытии в браузере: $e');
        debugPrint('❌ [Flicky] Тип ошибки: ${e.runtimeType}');
        _showErrorSnackBar(context.l10n.openServiceRetry(serviceName));
      }
    } else {
      debugPrint('✅ [Flicky] Успешно открыто в приложении');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showStreamingPlatforms() {
    if (_currentMovie == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StreamingPlatformsSheet(
        movieTitle: _currentMovie!.title,
        movieYear: _currentMovie!.releaseYear,
        onPlatformTap: _openStreamingService,
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push<FilterConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(
          initialConfig: FilterConfig(
            year: _filterYear,
            genreIds: _filterGenreIds,
            minRating: _filterMinRating,
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _filterYear = result.year;
        _filterGenreIds = result.genreIds;
        _filterMinRating = result.minRating;
        _shownMovieIds.clear();
      });
      await _loadRandomMovie();
    }
  }

  void _showMovieDetails() {
    if (_currentMovie == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: _currentMovie!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      extendBodyBehindAppBar: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Builder(
                  builder: (context) {
                    final hasFilters =
                        _filterYear != null || _filterGenreIds.isNotEmpty || _filterMinRating != null;
                    final icon = hasFilters
                        ? const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.amber)
                        : const Icon(Icons.error_outline, size: 64, color: Colors.red);
                    final title = hasFilters ? context.l10n.filtersWarningTitle : context.l10n.errorTitle;

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          icon,
                          const SizedBox(height: 16),
                          Text(
                            title,
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
                          if (hasFilters) ...[
                            ElevatedButton.icon(
                              onPressed: _openFilters,
                              icon: const Icon(Icons.tune),
                              label: Text(context.l10n.filtersChangeButton),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadRandomMovie,
                              icon: const Icon(Icons.refresh),
                              label: Text(context.l10n.tryAgain),
                            ),
                          ] else
                            ElevatedButton.icon(
                              onPressed: _loadRandomMovie,
                              icon: const Icon(Icons.refresh),
                              label: Text(context.l10n.tryAgain),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : _currentMovie == null
                  ? Center(child: Text(context.l10n.notFound))
                  : _buildMainScreenWithSwipe(),
    );
  }

  Widget _buildMainScreenWithSwipe() {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _dragStartX = details.globalPosition.dx;
          _swipeOffset = 0.0;
        });
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          final newOffset = details.globalPosition.dx - _dragStartX;
          // Плавное ограничение смещения с резиновым эффектом
          if (newOffset.abs() > 100) {
            _swipeOffset = newOffset > 0 
                ? 100 + (newOffset - 100) * 0.3 
                : -100 + (newOffset + 100) * 0.3;
          } else {
            _swipeOffset = newOffset;
          }
        });
      },
      onHorizontalDragEnd: (details) {
        // Если свайп был достаточно сильным
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -800 || _swipeOffset < -80) {
            // Свайп влево
            _loadRandomMovieWithAnimation('left');
          } else if (details.primaryVelocity! > 800 || _swipeOffset > 80) {
            // Свайп вправо
            _loadRandomMovieWithAnimation('right');
          } else {
            // Возвращаем на место, если свайп был слабым
            setState(() {
              _swipeOffset = 0.0;
            });
          }
        } else {
          setState(() {
            _swipeOffset = 0.0;
          });
        }
      },
      child: Stack(
        children: [
          // Затемняющий фон при свайпе
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: Colors.black.withOpacity(
              (_swipeOffset.abs() / 200).clamp(0.0, 0.7),
            ),
          ),
          // Контент с улучшенной анимацией
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(_swipeOffset, 0.0)
              ..scale(1.0 - (_swipeOffset.abs() / 400).clamp(0.0, 0.08)),
            child: Opacity(
              opacity: 1.0 - (_swipeOffset.abs() / 250).clamp(0.0, 0.4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) {
                  Offset beginOffset;
                  if (_swipeDirection == 'left') {
                    beginOffset = const Offset(0.5, 0); // Входит справа
                  } else if (_swipeDirection == 'right') {
                    beginOffset = const Offset(-0.5, 0); // Входит слева
                  } else {
                    beginOffset = const Offset(0.2, 0); // По умолчанию
                  }
                  
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: _buildMainScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRandomMovieWithAnimation(String direction) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _swipeDirection = direction; // Сохраняем направление для анимации
      _movieKey++; // Изменяем ключ для анимации
      _swipeOffset = 0.0; // Сбрасываем смещение
    });

    try {
      // Если показано много фильмов, очищаем кэш для разнообразия
      if (_shownMovieIds.length > 50) {
        _shownMovieIds.clear();
      }
      
      final lang = Localizations.localeOf(context).languageCode;
      final movie = await _tmdbService.getRandomMovie(
        excludeIds: _shownMovieIds,
        languageCode: lang,
        year: _filterYear,
        genreIds: _filterGenreIds.isEmpty ? null : _filterGenreIds,
        minRating: _filterMinRating,
      );
      if (movie != null) {
        setState(() {
          _currentMovie = movie;
          _shownMovieIds.add(movie.id); // Добавляем в кэш
          _isLoading = false;
        });
      } else {
        setState(() {
          final hasFilters = _filterYear != null || _filterGenreIds.isNotEmpty;
          _errorMessage = hasFilters ? context.l10n.noResultsForFilters : context.l10n.loadFailed;
          _isLoading = false;
        });
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('TMDB_API_KEY')) {
        errorMsg = context.l10n.apiKeyMissing;
      } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
        errorMsg = context.l10n.apiKeyInvalid;
      } else if (errorMsg.contains('network') || errorMsg.contains('Internet')) {
        errorMsg = context.l10n.networkIssue;
      } else {
        errorMsg = context.l10n.loadFailed;
      }
      
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
      
      _showErrorSnackBar(errorMsg);
    }
  }

  Widget _buildMainScreen() {
    return Stack(
      key: ValueKey<int>(_movieKey),
      children: [
        // Постер снизу с градиентом
        Positioned.fill(
          child: _currentMovie!.posterUrl != null
              ? Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _currentMovie!.posterUrl!,
                        fit: BoxFit.fitHeight,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.movie, size: 100, color: Colors.grey),
                          ),
                        ),
                      ),
                      // Градиент сверху
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                            stops: const [0.0, 0.3, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.movie, size: 100, color: Colors.grey),
                  ),
                ),
        ),
        // Контент
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_filterYear != null || _filterGenreIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.filterActiveLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      tooltip: context.l10n.filtersTitle,
                      onPressed: _openFilters,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Блок с названием и кнопками с полупрозрачным фоном
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Название и рейтинг
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _currentMovie!.title,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _currentMovie!.isTvShow 
                                        ? Colors.purple.withOpacity(0.8)
                                        : Colors.blue.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _currentMovie!.isTvShow ? Icons.tv : Icons.movie,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _currentMovie!.isTvShow ? context.l10n.badgeTv : context.l10n.badgeMovie,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_currentMovie!.voteAverage != null) ...[
                                const Icon(Icons.star, color: Colors.amber, size: 24),
                                const SizedBox(width: 6),
                                Text(
                                  _currentMovie!.voteAverage!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_currentMovie!.releaseYear != null) ...[
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _currentMovie!.releaseYear!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (_currentMovie!.releaseYear != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _currentMovie!.releaseYear!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Три кнопки действий
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.play_circle_filled,
                            label: 'Смотреть',
                            color: Colors.red,
                            onTap: _showStreamingPlatforms,
                          ),
                          _ActionButton(
                            icon: Icons.info_outline,
                            label: 'Информация',
                            color: Colors.blue,
                            onTap: _showMovieDetails,
                          ),
                          _ActionButton(
                            icon: Icons.auto_awesome,
                            label: 'Мне повезет',
                            color: Colors.purple,
                            onTap: _loadRandomMovie,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(35),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _StreamingPlatformsSheet extends StatelessWidget {
  final String movieTitle;
  final String? movieYear;
  final Function(String, String) onPlatformTap;

  const _StreamingPlatformsSheet({
    required this.movieTitle,
    this.movieYear,
    required this.onPlatformTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.whereToWatchTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  movieTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                // Кнопка быстрого поиска в Google
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      String searchQuery = movieTitle;
                      if (movieYear != null && movieYear!.isNotEmpty) {
                        searchQuery += ' $movieYear';
                      }
                      final url = 'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}';
                      final uri = Uri.parse(url);

                      if (!await canLaunchUrl(uri)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.searchOpenError)),
                        );
                        return;
                      }

                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                        } catch (e2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.l10n.searchOpenErrorRetry)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: Text(context.l10n.findInGoogle),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.availabilityWarning,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.amber[900],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'Netflix',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('netflix', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'Amazon Prime Video',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('amazon', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'Apple TV',
                  color: Colors.black,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('apple', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'Disney+',
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('disney', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'HBO Max',
                  color: Colors.deepPurple.shade300,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('hbomax', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: 'Amediateka',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('amediateka', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: context.l10n.iviLabel,
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('ivi', movieTitle);
                  },
                ),
                const SizedBox(height: 12),
                _StreamingButton(
                  icon: Icons.play_circle_outline,
                  label: context.l10n.kinopoiskLabel,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    onPlatformTap('kinopoisk', movieTitle);
                  },
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Future<void> _openTrailer(String trailerUrl) async {
    final uri = Uri.parse(trailerUrl);
    
    if (!await canLaunchUrl(uri)) {
      _showErrorSnackBar(context.l10n.trailerOpenError);
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e2) {
        _showErrorSnackBar(context.l10n.trailerOpenErrorRetry);
      }
    }
  }

  Future<void> _openGoogleSearch() async {
    String searchQuery = widget.movie.title;
    if (widget.movie.releaseYear != null) {
      searchQuery += ' ${widget.movie.releaseYear}';
    }
    
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}';
    final uri = Uri.parse(url);
    
    if (!await canLaunchUrl(uri)) {
      _showErrorSnackBar(context.l10n.searchOpenError);
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e2) {
        _showErrorSnackBar(context.l10n.searchOpenErrorRetry);
      }
    }
  }

  Future<void> _openStreamingService(String service, String movieTitle) async {
    String url;
    String serviceName;
    
    switch (service.toLowerCase()) {
      case 'netflix':
        url = 'https://www.netflix.com/search?q=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Netflix';
        break;
      case 'amazon':
        url = 'https://www.primevideo.com/search/ref=atv_sr?phrase=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Amazon Prime Video';
        break;
      case 'apple':
        url = 'https://tv.apple.com/search?term=${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Apple TV';
        break;
      case 'disney':
        url = 'https://www.disneyplus.com/search/${Uri.encodeComponent(movieTitle)}';
        serviceName = 'Disney+';
        break;
      case 'kinopoisk':
        url = 'https://www.kinopoisk.ru/index.php?kp_query=${Uri.encodeComponent(movieTitle)}';
        serviceName = context.l10n.kinopoiskLabel;
        break;
      default:
        return;
    }

    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);
    
    if (!canLaunch) {
      _showErrorSnackBar(context.l10n.openServiceInternetError(serviceName));
      return;
    }

    bool openedInApp = false;
    try {
      openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      // Игнорируем ошибку, пробуем браузер
    }

    if (!openedInApp) {
      try {
        final openedInBrowser = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!openedInBrowser) {
          try {
            final openedWebView = await launchUrl(uri, mode: LaunchMode.inAppWebView);
            if (!openedWebView) {
              try {
                await launchUrl(uri, mode: LaunchMode.platformDefault);
              } catch (e) {
                _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
              }
            }
          } catch (e) {
            try {
              await launchUrl(uri, mode: LaunchMode.platformDefault);
            } catch (e2) {
              _showErrorSnackBar(context.l10n.openServiceBrowserMissing(serviceName));
            }
          }
        }
      } catch (e) {
      _showErrorSnackBar(context.l10n.openServiceRetry(serviceName));
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie.isTvShow ? context.l10n.detailsTvTitle : context.l10n.detailsMovieTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Постер
            if (widget.movie.posterUrl != null)
              Container(
                height: 500,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.movie.posterUrl!,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.movie.title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.movie.isTvShow ? Colors.purple : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.movie.isTvShow ? Icons.tv : Icons.movie,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.movie.isTvShow ? context.l10n.badgeTv : context.l10n.badgeMovie,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Рейтинг и год
                  Row(
                    children: [
                      if (widget.movie.voteAverage != null) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          widget.movie.voteAverage!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (widget.movie.releaseYear != null)
                        Text(
                          widget.movie.releaseYear!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Жанры
                  if (widget.movie.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.movie.genres.map((genre) {
                        return Chip(
                          label: Text(genre.name),
                          backgroundColor: Colors.blue[50],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Описание
                  if (widget.movie.overview != null && widget.movie.overview!.isNotEmpty) ...[
                    Text(
                      context.l10n.overviewTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.movie.overview!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Трейлер
                  if (widget.movie.trailerKey != null) ...[
                    Text(
                      context.l10n.trailerTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _openTrailer(widget.movie.trailerUrl!),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                context.l10n.watchTrailer,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Поиск в Google
                  Text(
                    context.l10n.searchTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _openGoogleSearch,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.l10n.findInGoogle,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Кнопки стриминговых сервисов
                  Text(
                    context.l10n.watchOnTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.7),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.availabilityWarning,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Netflix
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: 'Netflix',
                    color: Colors.red,
                    onTap: () => _openStreamingService('netflix', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // Amazon Prime Video
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: 'Amazon Prime Video',
                    color: Colors.blue,
                    onTap: () => _openStreamingService('amazon', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // Apple TV
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: 'Apple TV',
                    color: Colors.black,
                    onTap: () => _openStreamingService('apple', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // HBO Max
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: 'HBO Max',
                    color: Colors.deepPurple.shade300,
                    onTap: () => _openStreamingService('hbomax', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // Amediateka
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: 'Amediateka',
                    color: Colors.redAccent,
                    onTap: () => _openStreamingService('amediateka', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // IVI
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: context.l10n.iviLabel,
                    color: Colors.deepPurple,
                    onTap: () => _openStreamingService('ivi', widget.movie.title),
                  ),
                  const SizedBox(height: 12),
                  
                  // Кинопоиск
                  _StreamingButton(
                    icon: Icons.play_circle_outline,
                    label: context.l10n.kinopoiskLabel,
                    color: Colors.orange,
                    onTap: () => _openStreamingService('kinopoisk', widget.movie.title),
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
