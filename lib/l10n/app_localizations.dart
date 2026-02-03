import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l10n != null, 'AppLocalizations is not found in context');
    return l10n!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[Locale('ru'), Locale('en')];

  bool get isRu => locale.languageCode == 'ru';

  // App
  String get appName => isRu ? 'Flicky' : 'Flicky';

  // Generic
  String get errorTitle => isRu ? 'Ошибка' : 'Error';
  String get tryAgain => isRu ? 'Попробовать снова' : 'Try again';
  String get notFound => isRu ? 'Не найдено' : 'Not found';

  // Content type
  String get badgeMovie => isRu ? 'Фильм' : 'Movie';
  String get badgeTv => isRu ? 'Сериал' : 'TV';

  // Details
  String get detailsMovieTitle => isRu ? 'Информация о фильме' : 'Movie details';
  String get detailsTvTitle => isRu ? 'Информация о сериале' : 'TV show details';
  String get overviewTitle => isRu ? 'Описание' : 'Overview';

  // Trailer
  String get trailerTitle => isRu ? 'Трейлер' : 'Trailer';
  String get watchTrailer => isRu ? 'Смотреть трейлер' : 'Watch trailer';
  String get trailerOpenError => isRu
      ? 'Не удалось открыть трейлер. Проверьте подключение к интернету.'
      : 'Could not open trailer. Please check your internet connection.';
  String get trailerOpenErrorRetry =>
      isRu ? 'Не удалось открыть трейлер. Попробуйте позже.' : 'Could not open trailer. Please try again later.';

  // Google search
  String get searchTitle => isRu ? 'Поиск' : 'Search';
  String get findInGoogle => isRu ? 'Найти в Google' : 'Find on Google';
  String get searchOpenError => isRu
      ? 'Не удалось открыть поиск. Проверьте подключение к интернету.'
      : 'Could not open search. Please check your internet connection.';
  String get searchOpenErrorRetry =>
      isRu ? 'Не удалось открыть поиск. Попробуйте позже.' : 'Could not open search. Please try again later.';

  // Watch platforms
  String get watchOnTitle => isRu ? 'Смотреть на:' : 'Watch on:';
  String get whereToWatchTitle => isRu ? 'Где смотреть' : 'Where to watch';
  String get kinopoiskLabel => isRu ? 'Кинопоиск' : 'Kinopoisk';
  String get iviLabel => isRu ? 'Иви' : 'ivi';
  String get availabilityWarning => isRu
      ? 'Внимание: фильм или сериал может быть недоступен на некоторых площадках. В этом случае вы можете воспользоваться поиском в Google выше.'
      : 'Note: the movie or TV show may not be available on some platforms. If so, you can use the Google search above.';

  // Filters
  String get filtersTitle => isRu ? 'Фильтры' : 'Filters';
  String get filterYear => isRu ? 'Год выпуска' : 'Year';
  String get filterGenre => isRu ? 'Жанры' : 'Genres';
  String get filterAnyYear => isRu ? 'Любой год' : 'Any year';
  String get filterRating => isRu ? 'Рейтинг' : 'Rating';
  String get filterAnyRating => isRu ? 'Любой рейтинг' : 'Any rating';
  String get filterApply => isRu ? 'Показать' : 'Apply';
  String get filterReset => isRu ? 'Сбросить' : 'Reset';
  String get filterActiveLabel => isRu ? 'Фильтры включены' : 'Filters active';
  String get filterResultsTitle => isRu ? 'Результаты' : 'Results';
  String get filterLoadMore => isRu ? 'Загрузить ещё' : 'Load more';
  String openServiceInternetError(String serviceName) => isRu
      ? 'Не удалось открыть $serviceName. Проверьте подключение к интернету.'
      : 'Could not open $serviceName. Please check your internet connection.';
  String openServiceBrowserMissing(String serviceName) => isRu
      ? 'Не удалось открыть $serviceName. Убедитесь, что у вас установлен браузер.'
      : 'Could not open $serviceName. Make sure a browser is installed.';
  String openServiceRetry(String serviceName) => isRu
      ? 'Не удалось открыть $serviceName. Попробуйте позже.'
      : 'Could not open $serviceName. Please try again later.';

  // Main actions (labels may be hidden on main, but kept for accessibility)
  String get actionWatch => isRu ? 'Смотреть' : 'Watch';
  String get actionInfo => isRu ? 'Информация' : 'Info';
  String get actionLucky => isRu ? 'Мне повезет' : "I'm feeling lucky";

  // Errors (content loading)
  String get apiKeyMissing => isRu ? 'API ключ не установлен. Проверьте файл .env' : 'API key is missing. Check your .env file.';
  String get apiKeyInvalid => isRu ? 'Неверный API ключ. Проверьте настройки' : 'Invalid API key. Check your settings.';
  String get networkIssue => isRu ? 'Проблема с подключением к интернету' : 'Network connection issue.';
  String get loadFailed => isRu ? 'Не удалось загрузить. Попробуйте снова' : 'Failed to load. Please try again.';

  // Filters – no results
  String get noResultsForFilters => isRu
      ? 'Фильмы или сериалы с указанными фильтрами не найдены. Попробуйте изменить фильтры.'
      : 'No movies or TV shows match the selected filters. Try adjusting your filters.';

  String get filtersWarningTitle => isRu ? 'Ничего не найдено' : 'Nothing found';
  String get filtersChangeButton =>
      isRu ? 'Изменить фильтры' : 'Adjust filters';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

