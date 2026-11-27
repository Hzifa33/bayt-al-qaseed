class AppConstants {
  AppConstants._();

  static const String appName = 'بيت القصيد';
  static const String appTagline = 'الموسوعة الشعرية الشاملة';
  static const String appVersion = '1.0.1';

  static const String developerHandle = 'hzifa33';
  static const String developerWebsite = 'https://hzifa33.com';
  static const String repositoryUrl =
      'https://github.com/Hzifa33/bayt-al-qaseed';

  static const String corpusAssetPath = 'assets/db/bayt_qafiyah_merged.db.xz';
  static const String corpusDbFileName = 'bayt_qafiyah_merged_v9.db';

  /// Minimum free internal storage required before starting extraction
  /// (~480 MB uncompressed raw-block SQLite DB + ~140 MB safety headroom).
  static const int corpusRequiredStorageBytes = 620 * 1024 * 1024;

  /// Approximate uncompressed DB size for UI progress display before completion.
  static const int corpusExpectedUncompressedBytes = 480 * 1024 * 1024;

  static const List<String> legacyCorpusDbFileNames = [
    'bayt_al_qaseed_v1.db',
    'bayt_al_qaseed_v2.db',
    'bayt_al_qaseed_v3.db',
    'bayt_al_qaseed_v4.db',
    'bayt_al_qaseed_v5.db',
    'bayt_qafiyah_merged_v6.db',
    'bayt_qafiyah_merged_v7.db',
    'bayt_qafiyah_merged_v8.db',
  ];

  static const String userDbFileName = 'bayt_user_data_v1.db';
  static const int corpusDbVersion = 9;
}
