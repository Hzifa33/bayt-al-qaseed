import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lossless 1-byte Arabic codec matching `tool/merge_databases.py`.
///
/// Encoding layout:
/// - `0x00..0x7E` -> ASCII directly (including `\t` and `\n`)
/// - `0x80..0xFF` -> Arabic Unicode block `U+0600..U+067F`
/// - `0x7F <len> <utf8...>` -> escape sequence for any other Unicode codepoint
class ArabicCodec {
  ArabicCodec._();

  static String unpack(Uint8List data, [int offset = 0, int? length]) {
    final end = length == null ? data.length : offset + length;
    if (offset < 0 || end > data.length || offset >= end) {
      return '';
    }
    final sb = StringBuffer();
    var i = offset;
    while (i < end) {
      final b = data[i];
      if (b < 0x7F) {
        sb.writeCharCode(b);
        i++;
      } else if (b >= 0x80) {
        sb.writeCharCode(0x0600 + (b & 0x7F));
        i++;
      } else {
        if (i + 1 >= end) break;
        final ln = data[i + 1];
        final sliceEnd = (i + 2 + ln <= end) ? i + 2 + ln : end;
        sb.write(utf8.decode(Uint8List.sublistView(data, i + 2, sliceEnd)));
        i = sliceEnd;
      }
    }
    return sb.toString();
  }

  static Uint8List decompressZlib(Uint8List compressed) {
    final decoded = zlib.decode(compressed);
    return decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
  }

  static String decodeCompressedText(Uint8List? compressed) {
    if (compressed == null || compressed.isEmpty) return '';
    return unpack(decompressZlib(compressed));
  }
}

/// Small bounded LRU cache for decompressed `content_blocks` (~16 blocks ≈ 2.5 MB RAM).
class BlockLruCache {
  BlockLruCache({this.capacity = 16});

  final int capacity;
  final LinkedHashMap<int, Uint8List> _map = LinkedHashMap<int, Uint8List>();

  Uint8List? get(int blockId) {
    final val = _map.remove(blockId);
    if (val != null) {
      _map[blockId] = val;
    }
    return val;
  }

  void put(int blockId, Uint8List data) {
    _map.remove(blockId);
    _map[blockId] = data;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();
}
