import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/poetry_database.dart';
import '../../data/datasources/user_database.dart';
import '../../data/repositories/poetry_repository.dart';
import '../../data/repositories/user_repository.dart';

class AppServices {
  const AppServices({
    required this.poetryDb,
    required this.userDb,
    required this.prefs,
  });

  final PoetryDatabase poetryDb;
  final UserDatabase userDb;
  final SharedPreferences prefs;
}

final appServicesProvider = StateProvider<AppServices?>((ref) => null);

final poetryRepositoryProvider = Provider<PoetryRepository>((ref) {
  final services = ref.watch(appServicesProvider);
  if (services == null) {
    throw StateError('AppServices not initialized yet.');
  }
  return PoetryRepository(services.poetryDb);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final services = ref.watch(appServicesProvider);
  if (services == null) {
    throw StateError('AppServices not initialized yet.');
  }
  return UserRepository(services.userDb);
});
