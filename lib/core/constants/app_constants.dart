class AppConstants {
  AppConstants._();

  static const String appName = 'بيت القصيد';
  static const String appTagline = 'ديوان الشعر العربي';
  static const String appVersion = '1.0.0';
  static const String developerHandle = 'hzifa33';
  static const String developerWebsite = 'https://hzifa33.com';
  static const String repositoryUrl =
      'https://github.com/Hzifa33/bayt-al-qaseed';

  static const String corpusAssetPath = 'assets/db/bayt_al_qaseed.db.gz';
  static const String corpusDbFileName = 'bayt_al_qaseed_v5.db';
  static const List<String> legacyCorpusDbFileNames = [
    'bayt_al_qaseed_v1.db',
    'bayt_al_qaseed_v2.db',
    'bayt_al_qaseed_v3.db',
    'bayt_al_qaseed_v4.db',
  ];
  static const String userDbFileName = 'bayt_user_data_v1.db';
  static const int corpusDbVersion = 5;
}
