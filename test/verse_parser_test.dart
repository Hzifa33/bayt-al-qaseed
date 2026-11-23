import 'package:bayt_al_qaseed/data/models/verse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Verse.parseBody & Mukhammas (5-hemistich) classification', () {
    test('detects and groups classical 2-2-1 Mukhammas stanzas as 1 verse each', () {
      const body =
          'تَنَشَّقَ مِن عَرفِ الصَبا ما تَنَشَّقا\tوَعاوَدَهُ ذِكرُ الصِبا فَتَشَوَّقا\n'
          'وَما زالَ لَمعُ البَرقِ لَمّا تَأَلَّقا\tيُهيبُ بِدَمعِ العَينِ حَتّى تَدَفَّقا\n'
          'وَهَل يَملِكُ الدَمعَ المَشوقُ المُصَبَّأُ\n'
          'خَليلَيَّ إِن أَجزَع فَقَد وَضَحَ العُذرُ\tوَإِن أَستَطِع صَبراً فَمِن شيمَتي الصَبرُ\n'
          'وَإِن يَكُ رُزأً ما أَصابَ بِهِ الدَهرُ\tفَفي يَومِنا خَمرٌ وَفي غَدِهِ أَمرُ\n'
          'وَلا عَجَبٌ إِنَّ الكَريمَ مُرَزَّأُ';

      final verses = Verse.parseBody(body);
      expect(verses.length, 2);
      expect(verses[0].isMukhammas, isTrue);
      expect(verses[0].allHemistichs.length, 5);
      expect(verses[0].index, 0);
      expect(verses[1].isMukhammas, isTrue);
      expect(verses[1].allHemistichs.length, 5);
      expect(verses[1].index, 1);

      // Raw line index mapping (raw row 4 belongs to stanza 1)
      expect(Verse.resolveGroupedIndex(verses, 0), 0);
      expect(Verse.resolveGroupedIndex(verses, 2), 0);
      expect(Verse.resolveGroupedIndex(verses, 4), 1);
      expect(Verse.resolveGroupedIndex(verses, 5), 1);
    });

    test('does not falsely group monorhyme single-hemistich Rajaz poems', () {
      const body =
          'زَيدُ بنُ عَمروٍ لَيسَ فيها صالِحُ\n'
          'قَبيلَةٌ لَيسَ لَها مُنادِحُ\n'
          'ذَلَّت فَما يَنبِحُ عَنها نابِحُ\n'
          'مِثلُ نَوى السَوءِ نَفاهُ الراضِحُ\n'
          'أَو كَعَصا السَوءِ بَراها الناقِحُ\n'
          'نِسائُهُم لِغَيرِهِم لَواقِحُ\n'
          'كُلُّهُمُ عَن مَجدِهِم كاشِحُ\n'
          'وَلَيسَ فيهِم سَيِّدٌ راجِحُ\n'
          'وَلا كَريمٌ بِالقِرى سامِحُ\n'
          'وَلا شُجاعٌ في الوَغى جارِحُ';

      final verses = Verse.parseBody(body);
      expect(verses.length, 10);
      expect(verses.every((v) => !v.isMukhammas && !v.isTwoHemistich), isTrue);
    });

    test('keeps regular 2-hemistich poems with stray single line ungrouped', () {
      const body =
          'عَلى قَدرِ أَهلِ العَزمِ تَأتي العَزائِمُ\tوَتَأتي عَلى قَدرِ الكِرامِ المَكارِمُ\n'
          'وَتَعظُمُ في عَينِ الصَغيرِ صِغارُها\tوَتَصغُرُ في عَينِ العَظيمِ العَظائِمُ\n'
          'يُكَلِّفُ سَيفُ الدَولَةِ الجَيشَ هَمَّهُ\tوَقَد عَجَزَت عَنهُ الجُيوشُ الخَضارِمُ\n'
          'شطر مفرد عارض';

      final verses = Verse.parseBody(body);
      expect(verses.length, 4);
      expect(verses[0].isTwoHemistich, isTrue);
      expect(verses[3].isTwoHemistich, isFalse);
      expect(verses[3].isMukhammas, isFalse);
    });
  });
}
