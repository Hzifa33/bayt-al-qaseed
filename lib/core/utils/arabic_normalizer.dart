import 'package:flutter/material.dart';

/// Arabic text normalization, FTS5 query builder, and diacritic-preserving highlighter.
///
/// Mirrors the exact normalization rules applied during SQLite FTS5 indexing:
/// - Remove tashkeel (harakat) and tatweel (kashida)
/// - Unify Alef forms: أ إ آ ٱ -> ا
/// - Unify Alef Maqsura: ى -> ي
/// - Unify Taa Marbuta: ة -> ه
class ArabicNormalizer {
  ArabicNormalizer._();

  static final RegExp _tashkeelRe = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  static bool _isTashkeel(int c) =>
      (c >= 0x064B && c <= 0x065F) ||
      (c >= 0x0610 && c <= 0x061A) ||
      c == 0x0670 ||
      (c >= 0x06D6 && c <= 0x06ED);

  static bool _isInvisibleFormat(int c) =>
      (c >= 0x200B && c <= 0x200F) ||
      (c >= 0x202A && c <= 0x202E) ||
      (c >= 0x2066 && c <= 0x2069) ||
      c == 0xFEFF;

  /// Removes Arabic diacritics (tashkeel) while preserving base letters & punctuation.
  /// Single-pass zero-RegExp implementation with zero-allocation fast path.
  static String stripDiacritics(String input) {
    final len = input.length;
    if (len == 0) return input;
    var firstDiacritic = -1;
    for (var i = 0; i < len; i++) {
      if (_isTashkeel(input.codeUnitAt(i))) {
        firstDiacritic = i;
        break;
      }
    }
    if (firstDiacritic == -1) return input;

    final buf = StringBuffer(input.substring(0, firstDiacritic));
    for (var i = firstDiacritic + 1; i < len; i++) {
      final c = input.codeUnitAt(i);
      if (!_isTashkeel(c)) {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }

  /// Normalizes Arabic text for search indexing & query matching.
  /// Single-pass UTF-16 code-unit loop (~10x faster than chained RegExp passes).
  static String normalize(String input) {
    final len = input.length;
    if (len == 0) return '';

    final buf = StringBuffer();
    var lastWasSpace = true;

    for (var i = 0; i < len; i++) {
      var c = input.codeUnitAt(i);
      if (_isTashkeel(c) || c == 0x0640 || _isInvisibleFormat(c)) continue;

      switch (c) {
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0622: // آ
        case 0x0671: // ٱ
          c = 0x0627; // ا
        case 0x0649: // ى
        case 0x06CC: // ی (Farsi yeh)
          c = 0x064A; // ي
        case 0x0629: // ة
          c = 0x0647; // ه
        case 0x06A9: // ک (Farsi kaf)
          c = 0x0643; // ك
      }

      if ((c >= 0x0621 && c <= 0x064A) || (c >= 0x0030 && c <= 0x0039)) {
        buf.writeCharCode(c);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        buf.writeCharCode(0x0020);
        lastWasSpace = true;
      }
    }

    final result = buf.toString();
    if (result.isNotEmpty && result.codeUnitAt(result.length - 1) == 0x0020) {
      return result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Splits user input into clean normalized tokens.
  static List<String> tokenize(String query) {
    final norm = normalize(query);
    if (norm.isEmpty) return const [];
    return norm.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Builds a safe SQLite FTS5 MATCH query from arbitrary Arabic user input.
  ///
  /// Uses prefix matching on the last token for instant type-ahead responsiveness
  /// when [prefixLastToken] is true, or exact phrase matching when [exactPhrase] is true.
  static String buildFts5Query(
    String rawQuery, {
    bool exactPhrase = false,
    bool prefixLastToken = true,
  }) {
    final tokens = tokenize(rawQuery);
    if (tokens.isEmpty) return '';

    if (exactPhrase && tokens.length > 1) {
      return '"${tokens.join(' ')}"';
    }

    if (tokens.length == 1) {
      final t = tokens.first;
      return (prefixLastToken && t.length >= 2) ? '$t*' : t;
    }

    final parts = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (prefixLastToken && i == tokens.length - 1 && t.length >= 2) {
        parts.add('$t*');
      } else {
        parts.add(t);
      }
    }
    return parts.join(' ');
  }

  /// Builds [TextSpan] list highlighting every occurrence of [rawQuery] tokens inside
  /// [originalText] while keeping the original Arabic tashkeel intact!
  static List<TextSpan> buildHighlightedSpans({
    required String originalText,
    required String rawQuery,
    required TextStyle baseStyle,
    required Color highlightBackground,
    required Color highlightForeground,
  }) {
    final tokens = tokenize(rawQuery);
    if (tokens.isEmpty || originalText.isEmpty) {
      return [TextSpan(text: originalText, style: baseStyle)];
    }

    // Build parallel normalized string + index map back to originalText code units.
    final normBuf = StringBuffer();
    final origIndices = <int>[];

    for (var i = 0; i < originalText.length; i++) {
      final ch = originalText[i];
      if (_tashkeelRe.hasMatch(ch) || ch == '\u0640') {
        continue;
      }
      String mapped;
      switch (ch) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          mapped = 'ا';
        case 'ى':
        case 'ی':
          mapped = 'ي';
        case 'ة':
          mapped = 'ه';
        case 'ک':
          mapped = 'ك';
        default:
          mapped = ch;
      }
      normBuf.write(mapped);
      origIndices.add(i);
    }

    final normText = normBuf.toString();
    if (normText.isEmpty) {
      return [TextSpan(text: originalText, style: baseStyle)];
    }

    // Find all matched ranges in originalText coordinates.
    final ranges = <(int, int)>[];
    for (final token in tokens) {
      if (token.isEmpty) continue;
      var searchFrom = 0;
      while (true) {
        final matchIdx = normText.indexOf(token, searchFrom);
        if (matchIdx == -1) break;
        final origStart = origIndices[matchIdx];
        final lastNormPos = matchIdx + token.length - 1;
        var origEnd = origIndices[lastNormPos] + 1;
        // Include any trailing diacritics attached to the final matched letter.
        while (origEnd < originalText.length &&
            (_tashkeelRe.hasMatch(originalText[origEnd]) ||
                originalText[origEnd] == '\u0640')) {
          origEnd++;
        }
        ranges.add((origStart, origEnd));
        searchFrom = matchIdx + token.length;
      }
    }

    if (ranges.isEmpty) {
      return [TextSpan(text: originalText, style: baseStyle)];
    }

    // Sort & merge overlapping ranges.
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.$1 > merged.last.$2) {
        merged.add(r);
      } else {
        final prev = merged.removeLast();
        merged.add((prev.$1, r.$2 > prev.$2 ? r.$2 : prev.$2));
      }
    }

    final highlightStyle = baseStyle.copyWith(
      backgroundColor: highlightBackground,
      color: highlightForeground,
      fontWeight: FontWeight.w700,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in merged) {
      if (r.$1 > cursor) {
        spans.add(
          TextSpan(
            text: originalText.substring(cursor, r.$1),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: originalText.substring(r.$1, r.$2),
          style: highlightStyle,
        ),
      );
      cursor = r.$2;
    }
    if (cursor < originalText.length) {
      spans.add(
        TextSpan(text: originalText.substring(cursor), style: baseStyle),
      );
    }
    return spans;
  }

  /// Converts ASCII digits to Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) with thousand separators.
  static String toArabicNumber(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    final len = s.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buf.write('٬');
      }
      final code = s.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        buf.writeCharCode(0x0660 + (code - 48));
      } else {
        buf.writeCharCode(code);
      }
    }
    return buf.toString();
  }
}
