class FavoriteVerseItem {
  const FavoriteVerseItem({
    required this.id,
    required this.poemId,
    required this.poetId,
    required this.verseIndex,
    required this.sadr,
    required this.ajuz,
    required this.poetName,
    required this.poemTitle,
    required this.createdAt,
  });

  final int id;
  final int poemId;
  final int poetId;
  final int verseIndex;
  final String sadr;
  final String ajuz;
  final String poetName;
  final String poemTitle;
  final DateTime createdAt;
}

class ReadingHistoryItem {
  const ReadingHistoryItem({
    required this.poemId,
    required this.poetId,
    required this.poetName,
    required this.poemTitle,
    required this.meterName,
    required this.verseCount,
    required this.lastVerseIndex,
    required this.updatedAt,
  });

  final int poemId;
  final int poetId;
  final String poetName;
  final String poemTitle;
  final String meterName;
  final int verseCount;
  final int lastVerseIndex;
  final DateTime updatedAt;
}

class UserCollection {
  const UserCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.poemCount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final int poemCount;
  final DateTime createdAt;
}
