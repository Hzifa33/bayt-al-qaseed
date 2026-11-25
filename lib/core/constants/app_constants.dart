class AppConstants {
  AppConstants._();

  /// Build-time edition flag: `standard` (default) or `expanded` («الموسوعة»).
  static const String edition = String.fromEnvironment(
    'EDITION',
    defaultValue: 'standard',
  );

  static const bool isExpanded = edition == 'expanded';

  static const String appName = isExpanded
      ? 'بيت القصيد — الموسوعة'
      : 'بيت القصيد';

  static const String appTagline = isExpanded
      ? 'الموسوعة الشعرية العربية الشاملة'
      : 'ديوان الشعر العربي';

  static const String appVersion = isExpanded ? '2.0.0' : '1.0.0';

  static const String developerHandle = 'hzifa33';
  static const String developerWebsite = 'https://hzifa33.com';
  static const String repositoryUrl =
      'https://github.com/Hzifa33/bayt-al-qaseed';

  static const String corpusAssetPath = isExpanded
      ? 'assets/db/bayt_qafiyah_merged.db.gz'
      : 'assets/db/bayt_al_qaseed.db.gz';

  static const String corpusDbFileName = isExpanded
      ? 'bayt_qafiyah_merged_v6.db'
      : 'bayt_al_qaseed_v5.db';

  static const List<String> legacyCorpusDbFileNames = [
    'bayt_al_qaseed_v1.db',
    'bayt_al_qaseed_v2.db',
    'bayt_al_qaseed_v3.db',
    'bayt_al_qaseed_v4.db',
  ];

  static const String userDbFileName = isExpanded
      ? 'bayt_expanded_user_data_v1.db'
      : 'bayt_user_data_v1.db';

  static const int corpusDbVersion = isExpanded ? 6 : 5;
}
