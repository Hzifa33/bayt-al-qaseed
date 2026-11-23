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
      String clean(String s) =>
          showDiacritics ? s : ArabicNormalizer.stripDiacritics(s);
      if (v.isMukhammas) {
        buf.writeln('${clean(v.sadr)}  ۞  ${clean(v.ajuz)}');
        buf.writeln(
          '${clean(v.extraHemistichs[0])}  ۞  ${clean(v.extraHemistichs[1])}',
        );
        buf.writeln(clean(v.extraHemistichs[2]));
        if (i < verses.length - 1) buf.writeln();
      } else {
        final sadr = clean(v.sadr);
        final ajuz = clean(v.ajuz);
        if (ajuz.isNotEmpty) {
          buf.writeln('$sadr  ۞  $ajuz');
        } else {
          buf.writeln(sadr);
        }
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
