import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

class SearchScreen extends StatefulWidget {
  final void Function(Movie) onMovieTap;

  const SearchScreen({super.key, required this.onMovieTap});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TMDbService _service = TMDbService();
  final TextEditingController _controller = TextEditingController();

  final List<Movie> _results = [];
  bool _isLoading = false;
  bool _hasMore = false;
  int _currentPage = 1;
  bool _hasSearched = false;

  bool _isLoadingCurated = false;
  bool _didLoadCurated = false;
  List<Movie> _curatedAction = [];
  List<Movie> _curatedPopular = [];
  List<Movie> _curatedRecentTv = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadCurated) {
      _didLoadCurated = true;
      _loadCurated();
    }
  }

  Future<void> _search({bool reset = true}) async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _results.clear();
      });
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      if (reset) {
        _results.clear();
        _currentPage = 1;
      }
    });

    try {
      final lang = Localizations.localeOf(context).languageCode;
      final page = reset ? 1 : _currentPage;
      final result = await _service.searchMoviesAndTv(
        languageCode: lang,
        query: query,
        page: page,
      );

      setState(() {
        _results.addAll(result.items);
        // Глобальная сортировка по рейтингу (по убыванию),
        // чтобы при догрузке страниц порядок сохранялся.
        _results.sort((a, b) {
          final ar = a.voteAverage ?? 0;
          final br = b.voteAverage ?? 0;
          return br.compareTo(ar);
        });
        _currentPage = result.nextPage;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(reset: true),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _search(reset: true),
                icon: const Icon(Icons.search),
                label: Text(l10n.searchButton),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildResults(context, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppLocalizations l10n) {
    if (!_hasSearched) {
      if (_isLoadingCurated) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView(
        children: [
          if (_curatedAction.isNotEmpty)
            _buildCuratedSection(
              title: l10n.curatedNew,
              movies: _curatedAction,
            ),
          if (_curatedPopular.isNotEmpty)
            _buildCuratedSection(
              title: l10n.curatedTopMovies,
              movies: _curatedPopular,
            ),
          if (_curatedRecentTv.isNotEmpty)
            _buildCuratedSection(
              title: l10n.curatedTopTv,
              movies: _curatedRecentTv,
            ),
          if (_curatedAction.isEmpty &&
              _curatedPopular.isEmpty &&
              _curatedRecentTv.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.searchHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
        ],
      );
    }

    if (_results.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          l10n.searchNoResults,
          textAlign: TextAlign.center,
        ),
      );
    }

    final extraItem = (_isLoading || _hasMore) ? 1 : 0;

    return ListView.builder(
      itemCount: _results.length + extraItem,
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
                                        movie.isTvShow ? l10n.badgeTv : l10n.badgeMovie,
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

        // Последний элемент: либо индикатор загрузки, либо кнопка "Загрузить ещё"
        if (_isLoading) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _search(reset: false),
                icon: const Icon(Icons.expand_more),
                label: Text(context.l10n.filterLoadMore),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCuratedSection({
    required String title,
    required List<Movie> movies,
  }) {
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

