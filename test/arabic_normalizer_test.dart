import 'package:bayt_al_qaseed/core/utils/arabic_normalizer.dart';
import 'package:bayt_al_qaseed/core/utils/share_formatter.dart';
import 'package:bayt_al_qaseed/data/models/verse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArabicNormalizer', () {
    test(
      'normalizes tashkeel, tatweel, alef, alef maqsura, and taa marbuta',
      () {
        expect(
          ArabicNormalizer.normalize('أَبُو الطَّيِّبِ الْمُتَنَبِّي'),
          equals('ابو الطيب المتنبي'),
        );
        expect(
          ArabicNormalizer.normalize('إِلى مَتىٰ — أُمامَةَ وَآلِها'),
          equals('الي متي امامه والها'),
        );
        expect(
          ArabicNormalizer.normalize('سَـيْـفُ الدَّوْلَةِ'),
          equals('سيف الدوله'),
        );
      },
    );

    test('strips diacritics while preserving letters and punctuation', () {
      expect(
        ArabicNormalizer.stripDiacritics(
          'لا تَعذُلِيهِ، فَإِنَّ العَذلَ يُولِعُهُ',
        ),
        equals('لا تعذليه، فإن العذل يولعه'),
      );
    });

    test('builds safe FTS5 queries for prefix and exact phrase modes', () {
      expect(ArabicNormalizer.buildFts5Query('قفا نبك'), equals('قفا نبك*'));
      expect(
        ArabicNormalizer.buildFts5Query('قفا نبك', exactPhrase: true),
        equals('"قفا نبك"'),
      );
      expect(ArabicNormalizer.buildFts5Query('   !@#   '), equals(''));
    });

    test(
      'highlights diacritized Arabic text when searching without tashkeel',
      () {
        const original = 'لا تَعذُلِيهِ فَإِنَّ العَذلَ يُولِعُهُ';
        const baseStyle = TextStyle(fontSize: 20, color: Colors.black);
        final spans = ArabicNormalizer.buildHighlightedSpans(
          originalText: original,
          rawQuery: 'تعذليه العذل',
          baseStyle: baseStyle,
          highlightBackground: Colors.amber,
          highlightForeground: Colors.brown,
        );

        // Reconstructed text must match original character-for-character
        final reconstructed = spans.map((s) => s.text ?? '').join();
        expect(reconstructed, equals(original));

        // Exactly two highlighted spans should exist
        final highlighted = spans
            .where((s) => s.style?.backgroundColor == Colors.amber)
            .toList();
        expect(highlighted.length, equals(2));
        expect(highlighted[0].text, equals('تَعذُلِيهِ'));
        expect(highlighted[1].text, equals('العَذلَ'));
      },
    );

    test('converts numbers to Eastern Arabic numerals with separators', () {
      expect(ArabicNormalizer.toArabicNumber(542), equals('٥٤٢'));
      expect(ArabicNormalizer.toArabicNumber(90238), equals('٩٠٬٢٣٨'));
      expect(ArabicNormalizer.toArabicNumber(1162119), equals('١٬١٦٢٬١١٩'));
    });
  });

  group('Verse & ShareFormatter', () {
    test('parses classical two-hemistich and single-hemistich poem bodies', () {
      final verses = Verse.parseBody(
        'خَليلَيَّ لا تَستَعجِلا\tوَأَن تَجمَعا شَملي\nسطر حر منفرد',
      );
      expect(verses.length, equals(2));
      expect(verses[0].isTwoHemistich, isTrue);
      expect(verses[0].sadr, equals('خَليلَيَّ لا تَستَعجِلا'));
      expect(verses[0].ajuz, equals('وَأَن تَجمَعا شَملي'));
      expect(verses[1].isTwoHemistich, isFalse);
      expect(verses[1].ajuz, isEmpty);
    });

    test('formats verses cleanly for text sharing', () {
      final formatted = ShareFormatter.formatVerses(
        verses: const [
          Verse(
            index: 0,
            sadr: 'عَلى قَدرِ أَهلِ العَزمِ',
            ajuz: 'تَأتي العَزائِمُ',
          ),
        ],
        poetName: 'أبو الطيب المتنبي',
        meterName: 'الطويل',
        showDiacritics: false,
      );
      expect(formatted, contains('على قدر أهل العزم'));
      expect(formatted, contains('أبو الطيب المتنبي'));
      expect(formatted, contains('بحر الطويل'));
    });
  });
}
