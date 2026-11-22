import '../../data/models/verse.dart';
import 'arabic_normalizer.dart';

class ShareFormatter {
  ShareFormatter._();

  static String formatVerses({
    required List<Verse> verses,
    required String poetName,
    String? meterName,
    bool showDiacritics = true,
    bool includeAttribution = true,
  }) {
    final buf = StringBuffer();
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      final sadr = showDiacritics
          ? v.sadr
          : ArabicNormalizer.stripDiacritics(v.sadr);
      final ajuz = showDiacritics
          ? v.ajuz
          : ArabicNormalizer.stripDiacritics(v.ajuz);
      if (ajuz.isNotEmpty) {
        buf.writeln('$sadr  ۞  $ajuz');
      } else {
        buf.writeln(sadr);
      }
    }
    buf.writeln();
    buf.write('— $poetName');
    if (meterName != null && meterName.isNotEmpty && meterName != 'غير مصنّف') {
      buf.write(' (بحر $meterName)');
    }
    if (includeAttribution) {
      buf.write('\nمن تطبيق «بيت القصيد»');
    }
    return buf.toString().trim();
  }
}
