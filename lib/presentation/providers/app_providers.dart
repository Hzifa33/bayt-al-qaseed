import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/era.dart';
import '../../data/models/meter.dart';
import '../../data/models/poem.dart';
import '../../data/models/poet.dart';
import '../../data/models/verse.dart';
import 'database_providers.dart';
import 'user_data_providers.dart';

final libraryStatsProvider = Provider<LibraryStats>((ref) {
  return ref.watch(poetryRepositoryProvider).getLibraryStats();
});

final erasProvider = Provider<List<Era>>((ref) {
  return ref.watch(poetryRepositoryProvider).getEras();
});

final metersProvider = Provider<List<Meter>>((ref) {
  return ref.watch(poetryRepositoryProvider).getMeters();
});

final rhymesProvider = Provider<List<Rhyme>>((ref) {
  return ref.watch(poetryRepositoryProvider).getRhymes();
});

final verseOfTheDayProvider = Provider<FeaturedVerse?>((ref) {
  return ref.watch(poetryRepositoryProvider).getVerseOfTheDay();
});

final masterpiecesProvider = Provider<List<FeaturedVerse>>((ref) {
  return ref.watch(poetryRepositoryProvider).getFeaturedMasterpieces(limit: 80);
});

final favoritePoemsListProvider = Provider<List<PoemSummary>>((ref) {
  ref.watch(userDataProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final poetryRepo = ref.watch(poetryRepositoryProvider);
  final ids = userRepo.getFavoritePoemIdsOrdered();
  return poetryRepo.getPoemsByIds(ids);
});

final favoritePoetsListProvider = Provider<List<Poet>>((ref) {
  ref.watch(userDataProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final poetryRepo = ref.watch(poetryRepositoryProvider);
  final ids = userRepo.getFavoritePoetIdsOrdered();
  return poetryRepo.getPoetsByIds(ids);
});
