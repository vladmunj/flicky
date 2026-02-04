import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

class FilterConfig {
  final int? year;
  final List<int> genreIds;
  final double? minRating;
  final String? countryCode;

  const FilterConfig({
    this.year,
    this.genreIds = const [],
    this.minRating,
    this.countryCode,
  });
}

class FilterScreen extends StatefulWidget {
  final FilterConfig? initialConfig;
  final void Function(Movie) onMovieTap;

  const FilterScreen({
    super.key,
    this.initialConfig,
    required this.onMovieTap,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final TMDbService _service = TMDbService();
  final Set<int> _selectedGenres = {};
  int? _selectedYear;
  double? _selectedMinRating;
  String? _selectedCountryCode;

  bool _isLoading = false;
  bool _didLoadGenres = false;
  bool _didLoadCountries = false;
  List<Genre> _genres = [];
  List<Country> _countries = [];

  final List<Movie> _results = [];
  bool _isLoadingResults = false;
  bool _hasMoreResults = false;
  int _currentPage = 1;
  bool _hasSearched = false;

  bool _isLoadingCurated = false;
  List<Movie> _curatedAction = [];
  List<Movie> _curatedPopular = [];
  List<Movie> _curatedRecentTv = [];
  bool _didAutoApply = false;

  bool get _hasInitialFilters =>
      _selectedYear != null ||
      _selectedGenres.isNotEmpty ||
      _selectedMinRating != null ||
      (_selectedCountryCode != null && _selectedCountryCode!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConfig;
    if (initial != null) {
      _selectedYear = initial.year;
      _selectedGenres.addAll(initial.genreIds);
      _selectedMinRating = initial.minRating;
      _selectedCountryCode = initial.countryCode;
    }

    // Если пришли с уже заданными фильтрами (например, из жанра),
    // автоматически загружаем результаты один раз.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didAutoApply && _hasInitialFilters) {
        _didAutoApply = true;
        _apply();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadGenres) {
      _didLoadGenres = true;
      _loadGenres();
      _loadCurated();
    }
    if (!_didLoadCountries) {
      _didLoadCountries = true;
      _loadCountries();
    }
  }

  Future<void> _loadGenres() async {
    setState(() => _isLoading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final genres = await _service.fetchMovieGenres(languageCode: lang);
      setState(() {
        _genres = genres;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await _service.fetchCountries();
      setState(() {
        _countries = countries;
      });
    } catch (_) {
      // Игнорируем ошибки загрузки стран
    }
  }

  void _apply() {
    setState(() {
      _hasSearched = true;
      _results.clear();
      _currentPage = 1;
      _hasMoreResults = false;
    });
    _loadResults(reset: true);
  }

  void _reset() {
    // Возвращаемся на главный экран с полностью сброшенными фильтрами
    Navigator.pop(
      context,
      const FilterConfig(
        year: null,
        genreIds: [],
        minRating: null,
        countryCode: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(60, (i) => currentYear - i);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filtersTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Год
                  Text(
                    l10n.filterYear,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<int?>(
                      value: _selectedYear,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(l10n.filterAnyYear),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.filterAnyYear),
                        ),
                        ...years.map(
                          (y) => DropdownMenuItem<int?>(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedYear = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Рейтинг
                  Text(
                    l10n.filterRating,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<double?>(
                      value: _selectedMinRating,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(l10n.filterAnyRating),
                      items: <double?>[null, 5.0, 6.0, 7.0, 8.0].map((value) {
                        if (value == null) {
                          return DropdownMenuItem<double?>(
                            value: null,
                            child: Text(l10n.filterAnyRating),
                          );
                        }
                        return DropdownMenuItem<double?>(
                          value: value,
                          child: Text('${value.toStringAsFixed(0)}+'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedMinRating = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Страна
                  Text(
                    l10n.filterCountry,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String?>(
                      value: _selectedCountryCode,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(l10n.filterAnyCountry),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.filterAnyCountry),
                        ),
                        ..._countries.map(
                          (country) => DropdownMenuItem<String?>(
                            value: country.code,
                            child: Text(country.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCountryCode = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Жанры
                  Text(
                    l10n.filterGenre,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_genres.isEmpty)
                    Text(
                      l10n.notFound,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _genres.map((genre) {
                        final selected = _selectedGenres.contains(genre.id);
                        return FilterChip(
                          label: Text(genre.name),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedGenres.add(genre.id);
                              } else {
                                _selectedGenres.remove(genre.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  // Кнопки действий
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _reset,
                          child: Text(l10n.filterReset),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _apply,
                          child: Text(l10n.filterApply),
                        ),
                      ),
                    ],
                  ),

                  // Подборки под фильтрами (до результатов)
                  if (!_hasSearched) ...[
                    const SizedBox(height: 24),
                    _buildCuratedBlocks(l10n),
                  ],

                  // Результаты
                  if (_hasSearched) ...[
                    const SizedBox(height: 24),
                    Text(
                      l10n.filterResultsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_results.isEmpty && !_isLoadingResults)
                      Text(
                        l10n.noResultsForFilters,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _results.length + ((_isLoadingResults || _hasMoreResults) ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < _results.length) {
                            final movie = _results[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => widget.onMovieTap(movie),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Постер
                                      if (movie.posterUrl != null)
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          child: Image.network(
                                            movie.posterUrl!,
                                            width: 80,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 80,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              bottomLeft: Radius.circular(12),
                                            ),
                                          ),
                                          child: const Icon(Icons.movie, color: Colors.white70),
                                        ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      movie.title,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: movie.isTvShow
                                                          ? Colors.purple.withOpacity(0.9)
                                                          : Colors.blue.withOpacity(0.9),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          movie.isTvShow ? Icons.tv : Icons.movie,
                                                          size: 14,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          movie.isTvShow
                                                              ? l10n.badgeTv
                                                              : l10n.badgeMovie,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  if (movie.voteAverage != null) ...[
                                                    const Icon(Icons.star,
                                                        size: 16, color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      movie.voteAverage!.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                  if (movie.releaseYear != null) ...[
                                                    if (movie.voteAverage != null)
                                                      const SizedBox(width: 12),
                                                    Text(
                                                      movie.releaseYear!,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // Последний элемент: либо индикатор, либо кнопка "Загрузить ещё"
                          if (_isLoadingResults) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (_hasMoreResults) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () => _loadResults(),
                                  icon: const Icon(Icons.expand_more),
                                  label: Text(l10n.filterLoadMore),
                                ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _loadResults({bool reset = false}) async {
    if (_isLoadingResults) return;
    setState(() {
      _isLoadingResults = true;
    });

    try {
      final lang = Localizations.localeOf(context).languageCode;
      final page = reset ? 1 : _currentPage;
      final result = await _service.discoverMoviesAndTv(
        languageCode: lang,
        year: _selectedYear,
        genreIds: _selectedGenres.toList(),
        minRating: _selectedMinRating,
        countryCode: _selectedCountryCode,
        page: page,
      );

      setState(() {
        if (reset) {
          _results
            ..clear()
            ..addAll(result.items);
        } else {
          _results.addAll(result.items);
        }
        _currentPage = result.nextPage;
        _hasMoreResults = result.hasMore;
        _isLoadingResults = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingResults = false;
        _hasMoreResults = false;
      });
    }
  }

  Future<void> _loadCurated() async {
    setState(() {
      _isLoadingCurated = true;
    });
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final action = await _service.getCuratedNew(languageCode: lang);
      final popular = await _service.getCuratedTopRatedMovies(languageCode: lang);
      final recentTv = await _service.getCuratedTopRatedTv(languageCode: lang);
      setState(() {
        _curatedAction = action;
        _curatedPopular = popular;
        _curatedRecentTv = recentTv;
        _isLoadingCurated = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingCurated = false;
      });
    }
  }

  Widget _buildCuratedBlocks(AppLocalizations l10n) {
    if (_isLoadingCurated) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    List<Widget> children = [];
    if (_curatedAction.isNotEmpty) {
      children.add(_buildCuratedSection(l10n.curatedNew, _curatedAction));
    }
    if (_curatedPopular.isNotEmpty) {
      children.add(_buildCuratedSection(l10n.curatedTopMovies, _curatedPopular));
    }
    if (_curatedRecentTv.isNotEmpty) {
      children.add(_buildCuratedSection(l10n.curatedTopTv, _curatedRecentTv));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCuratedSection(String title, List<Movie> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = movies[index];
                return InkWell(
                  onTap: () => widget.onMovieTap(movie),
                  child: SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: movie.posterUrl != null
                              ? Image.network(
                                  movie.posterUrl!,
                                  width: 130,
                                  height: 170,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 130,
                                  height: 170,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.movie,
                                      color: Colors.white70, size: 40),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

