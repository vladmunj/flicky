import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../l10n/app_localizations.dart';
import 'movie_screen.dart';

class ActorFilmographyScreen extends StatefulWidget {
  final CastMember castMember;

  const ActorFilmographyScreen({super.key, required this.castMember});

  @override
  State<ActorFilmographyScreen> createState() => _ActorFilmographyScreenState();
}

class _ActorFilmographyScreenState extends State<ActorFilmographyScreen> {
  final TMDbService _service = TMDbService();
  List<Movie> _credits = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilmography();
    });
  }

  Future<void> _loadFilmography() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = Localizations.localeOf(context).languageCode;
      final credits = await _service.fetchPersonFilmography(
        personId: widget.castMember.id,
        languageCode: lang,
      );
      if (!mounted) return;
      setState(() {
        _credits = credits;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.castMember.name),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.errorTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFilmography,
              child: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    if (_credits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            context.l10n.searchNoResults,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _credits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final movie = _credits[index];
        return ListTile(
          leading: movie.posterUrl != null
              ? CachedNetworkImage(
                  imageUrl: movie.posterUrl!,
                  width: 50,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.movie),
          title: Text(movie.title),
          subtitle: Row(
            children: [
              if (movie.releaseYear != null) ...[
                Text(
                  movie.releaseYear!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
              ],
              if (movie.voteAverage != null) ...[
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  movie.voteAverage!.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieDetailsScreen(movie: movie),
              ),
            );
          },
        );
      },
    );
  }
}

