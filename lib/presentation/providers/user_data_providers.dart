import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/poem.dart';
import '../../data/models/user_collection.dart';
import '../../data/models/verse.dart';
import '../../data/repositories/user_repository.dart';
import 'database_providers.dart';

class UserDataState {
  const UserDataState({
    this.favoritePoemIds = const {},
    this.favoritePoetIds = const {},
    this.favoriteVerses = const [],
    this.readingHistory = const [],
    this.collections = const [],
    this.revision = 0,
  });

  final Set<int> favoritePoemIds;
  final Set<int> favoritePoetIds;
  final List<FavoriteVerseItem> favoriteVerses;
  final List<ReadingHistoryItem> readingHistory;
  final List<UserCollection> collections;
  final int revision;

  ReadingHistoryItem? get lastRead =>
      readingHistory.isEmpty ? null : readingHistory.first;
}

class UserDataNotifier extends StateNotifier<UserDataState> {
  UserDataNotifier(this._repo) : super(const UserDataState()) {
    refresh();
  }

  final UserRepository _repo;

  void refresh() {
    state = UserDataState(
      favoritePoemIds: _repo.getFavoritePoemIdsSet(),
      favoritePoetIds: _repo.getFavoritePoetIdsSet(),
      favoriteVerses: _repo.getFavoriteVerses(),
      readingHistory: _repo.getReadingHistory(),
      collections: _repo.getCollections(),
      revision: state.revision + 1,
    );
  }

  bool toggleFavoritePoem(int poemId) {
    final added = _repo.toggleFavoritePoem(poemId);
    refresh();
    return added;
  }

  bool toggleFavoritePoet(int poetId) {
    final added = _repo.toggleFavoritePoet(poetId);
    refresh();
    return added;
  }

  void saveFavoriteVerses(PoemDetail poem, List<Verse> verses) {
    _repo.saveFavoriteVerses(poem: poem, verses: verses);
    refresh();
  }

  void removeFavoriteVerse(int id) {
    _repo.removeFavoriteVerse(id);
    refresh();
  }

  void recordReading(PoemDetail poem, {int lastVerseIndex = 0}) {
    _repo.recordReading(poem, lastVerseIndex: lastVerseIndex);
    refresh();
  }

  void clearHistory() {
    _repo.clearReadingHistory();
    refresh();
  }

  void removeHistoryItem(int poemId) {
    _repo.removeReadingHistoryItem(poemId);
    refresh();
  }

  void clearFavoritePoems() {
    _repo.clearFavoritePoems();
    refresh();
  }

  void clearFavoriteVerses() {
    _repo.clearFavoriteVerses();
    refresh();
  }

  void clearFavoritePoets() {
    _repo.clearFavoritePoets();
    refresh();
  }

  void clearAllCollections() {
    _repo.clearAllCollections();
    refresh();
  }

  int createCollection(String name, {String description = ''}) {
    final id = _repo.createCollection(name, description: description);
    refresh();
    return id;
  }

  void deleteCollection(int id) {
    _repo.deleteCollection(id);
    refresh();
  }

  bool togglePoemInCollection(int collectionId, int poemId) {
    final added = _repo.togglePoemInCollection(collectionId, poemId);
    refresh();
    return added;
  }

  Set<int> getCollectionIdsForPoem(int poemId) =>
      _repo.getCollectionIdsForPoem(poemId);

  Map<String, dynamic> exportAllUserData() => _repo.exportAllUserData();

  int importUserData(Map<String, dynamic> data) {
    final count = _repo.importUserData(data);
    refresh();
    return count;
  }
}

final userDataProvider = StateNotifierProvider<UserDataNotifier, UserDataState>(
  (ref) {
    final repo = ref.watch(userRepositoryProvider);
    return UserDataNotifier(repo);
  },
);
