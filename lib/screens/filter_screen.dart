import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';

class FilterConfig {
  final int? year;
  final List<int> genreIds;
  final double? minRating;

  const FilterConfig({
    this.year,
    this.genreIds = const [],
    this.minRating,
  });
}

class FilterScreen extends StatefulWidget {
  final FilterConfig? initialConfig;

  const FilterScreen({super.key, this.initialConfig});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final TMDbService _service = TMDbService();
  final Set<int> _selectedGenres = {};
  int? _selectedYear;
  double? _selectedMinRating;

  bool _isLoading = false;
  bool _didLoadGenres = false;
  List<Genre> _genres = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConfig;
    if (initial != null) {
      _selectedYear = initial.year;
      _selectedGenres.addAll(initial.genreIds);
      _selectedMinRating = initial.minRating;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadGenres) {
      _didLoadGenres = true;
      _loadGenres();
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

  void _apply() {
    Navigator.pop(
      context,
      FilterConfig(
        year: _selectedYear,
        genreIds: _selectedGenres.toList(),
        minRating: _selectedMinRating,
      ),
    );
  }

  void _reset() {
    // Возвращаемся на главный экран с полностью сброшенными фильтрами
    Navigator.pop(
      context,
      const FilterConfig(
        year: null,
        genreIds: [],
        minRating: null,
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
                ],
              ),
            ),
    );
  }
}

