import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../data/models/verse.dart';

enum _CardAspect {
  square('مربع ١:١', 1.0),
  post('منشور ٤:٥', 4 / 5),
  story('ستوري ٩:١٦', 9 / 16);

  const _CardAspect(this.label, this.ratio);
  final String label;
  final double ratio;
}

class _CardTemplate {
  const _CardTemplate({
    required this.name,
    required this.bgTop,
    required this.bgBottom,
    required this.ink,
    required this.accent,
    required this.border,
  });

  final String name;
  final Color bgTop;
  final Color bgBottom;
  final Color ink;
  final Color accent;
  final Color border;
}

const _templates = [
  _CardTemplate(
    name: 'مخطوط ورقي',
    bgTop: Color(0xFFFAF6EE),
    bgBottom: Color(0xFFEEE4D0),
    ink: Color(0xFF1D1A16),
    accent: Color(0xFF8C5E35),
    border: Color(0xFFCBB894),
  ),
  _CardTemplate(
    name: 'ليلي فاخر',
    bgTop: Color(0xFF171613),
    bgBottom: Color(0xFF0E0E0C),
    ink: Color(0xFFEBE4D6),
    accent: Color(0xFFC5A567),
    border: Color(0xFF3E3526),
  ),
  _CardTemplate(
    name: 'زمرد أندلسي',
    bgTop: Color(0xFF132A22),
    bgBottom: Color(0xFF0B1914),
    ink: Color(0xFFF0EAD9),
    accent: Color(0xFFD2B275),
    border: Color(0xFF2E4D40),
  ),
  _CardTemplate(
    name: 'عنّابي دمشقي',
    bgTop: Color(0xFF2F151A),
    bgBottom: Color(0xFF1B0C0F),
    ink: Color(0xFFF3ECE2),
    accent: Color(0xFFD5B17E),
    border: Color(0xFF562C34),
  ),
  _CardTemplate(
    name: 'كحلي ليلي',
    bgTop: Color(0xFF141B2B),
    bgBottom: Color(0xFF0B101A),
    ink: Color(0xFFECEAE4),
    accent: Color(0xFFCFA968),
    border: Color(0xFF2C3852),
  ),
];

const _cardFonts = <(String, String)>[
  ('شهرزاد', AppFonts.scheherazade),
  ('رُودو', AppFonts.ruwudu),
  ('جلزار', AppFonts.gulzar),
  ('الرقعة', AppFonts.ruqaa),
  ('نوتو نسخ', AppFonts.notoNaskh),
];

/// High-Resolution Editorial Poetry Card Generator Studio.
class PoetryCardStudioScreen extends StatefulWidget {
  const PoetryCardStudioScreen({
    super.key,
    required this.verses,
    required this.poetName,
    this.eraName,
    this.meterName,
  });

  final List<Verse> verses;
  final String poetName;
  final String? eraName;
  final String? meterName;

  @override
  State<PoetryCardStudioScreen> createState() => _PoetryCardStudioScreenState();
}

class _PoetryCardStudioScreenState extends State<PoetryCardStudioScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  int _templateIndex = 0;
  _CardAspect _aspect = _CardAspect.post;
  String _fontFamily = AppFonts.scheherazade;
  double _fontSize = 21;
  bool _staggered = true;
  bool _showDiacritics = true;
  bool _showPoet = true;
  bool _showWatermark = true;
  bool _exporting = false;

  Future<void> _exportAndShare() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tmpDir = await getTemporaryDirectory();
      final filename =
          'bayt_al_qaseed_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path.join(tmpDir.path, filename));
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/png'),
      ], text: '${widget.poetName} — من تطبيق «${AppConstants.appName}»');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر تصدير البطاقة: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tpl = _templates[_templateIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو البطاقات الشعرية'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: FilledButton.icon(
              onPressed: _exporting ? null : _exportAndShare,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text('تصدير'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live High-Res Preview Stage
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: AspectRatio(
                  aspectRatio: _aspect.ratio,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: _CardCanvas(
                      template: tpl,
                      verses: widget.verses,
                      poetName: widget.poetName,
                      eraName: widget.eraName,
                      fontFamily: _fontFamily,
                      fontSize: _fontSize,
                      staggered: _staggered,
                      showDiacritics: _showDiacritics,
                      showPoet: _showPoet,
                      showWatermark: _showWatermark,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Studio Controls Drawer
          Container(
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              border: Border(top: BorderSide(color: p.hairline)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Template Swatches
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _templates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final t = _templates[i];
                          final sel = i == _templateIndex;
                          return InkWell(
                            onTap: () => setState(() => _templateIndex = i),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [t.bgTop, t.bgBottom],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: sel ? t.accent : t.border,
                                  width: sel ? 2.2 : 1,
                                ),
                              ),
                              child: Text(
                                t.name,
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: t.ink,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Aspect Ratio + Font Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._CardAspect.values.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                selected: _aspect == a,
                                label: Text(a.label),
                                onSelected: (_) => setState(() => _aspect = a),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ..._cardFonts.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                selected: _fontFamily == f.$2,
                                label: Text(
                                  f.$1,
                                  style: TextStyle(fontFamily: f.$2),
                                ),
                                onSelected: (_) =>
                                    setState(() => _fontFamily = f.$2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Font size slider
                    Row(
                      children: [
                        Text(
                          'الحجم',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 14,
                            max: 30,
                            activeColor: p.accent,
                            onChanged: (v) => setState(() => _fontSize = v),
                          ),
                        ),
                      ],
                    ),

                    // Compact Toggle Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilterChip(
                          selected: _staggered,
                          label: Text(_staggered ? 'متدرّج' : 'متقابل'),
                          onSelected: (v) => setState(() => _staggered = v),
                        ),
                        FilterChip(
                          selected: _showDiacritics,
                          label: const Text('التشكيل'),
                          onSelected: (v) =>
                              setState(() => _showDiacritics = v),
                        ),
                        FilterChip(
                          selected: _showPoet,
                          label: const Text('توقيع الشاعر'),
                          onSelected: (v) => setState(() => _showPoet = v),
                        ),
                        FilterChip(
                          selected: _showWatermark,
                          label: const Text('شعار «بيت القصيد»'),
                          onSelected: (v) => setState(() => _showWatermark = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCanvas extends StatelessWidget {
  const _CardCanvas({
    required this.template,
    required this.verses,
    required this.poetName,
    required this.eraName,
    required this.fontFamily,
    required this.fontSize,
    required this.staggered,
    required this.showDiacritics,
    required this.showPoet,
    required this.showWatermark,
  });

  final _CardTemplate template;
  final List<Verse> verses;
  final String poetName;
  final String? eraName;
  final String fontFamily;
  final double fontSize;
  final bool staggered;
  final bool showDiacritics;
  final bool showPoet;
  final bool showWatermark;

  String _clean(String s) =>
      showDiacritics ? s : ArabicNormalizer.stripDiacritics(s);

  @override
  Widget build(BuildContext context) {
    final verseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 2.0,
      color: template.ink,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [template.bgTop, template.bgBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: template.border.withValues(alpha: 0.75),
              width: 1.1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Subtle Top Ornament
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 28, height: 0.8, color: template.accent),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          border: Border.all(color: template.accent, width: 1),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 28, height: 0.8, color: template.accent),
                ],
              ),

              // Verses Body (auto-scaled neatly inside card bounds)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: verses.map((v) {
                          final sadr = _clean(v.sadr);
                          final ajuz = _clean(v.ajuz);
                          if (!v.isTwoHemistich) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                sadr,
                                textAlign: TextAlign.center,
                                style: verseStyle,
                              ),
                            );
                          }
                          if (staggered) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    sadr,
                                    textAlign: TextAlign.right,
                                    style: verseStyle,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 26),
                                    child: Text(
                                      ajuz,
                                      textAlign: TextAlign.left,
                                      style: verseStyle,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(sadr, style: verseStyle),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(ajuz, style: verseStyle),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              // Footer Signature & Watermark
              Column(
                children: [
                  if (showPoet) ...[
                    Text(
                      poetName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: template.accent,
                      ),
                    ),
                    if (eraName != null && eraName!.isNotEmpty)
                      Text(
                        'العصر $eraName',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.5,
                          color: template.ink.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                  if (showWatermark) ...[
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontFamily: AppFonts.kufi,
                        fontSize: 11,
                        letterSpacing: 0.4,
                        color: template.ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
