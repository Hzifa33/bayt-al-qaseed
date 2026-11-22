import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../data/models/verse.dart';

enum _CardAspect {
  square('مربع ١:١', 1.0, Icons.crop_square_rounded),
  post('منشور ٤:٥', 4 / 5, Icons.crop_portrait_rounded),
  story('قصة ٩:١٦', 9 / 16, Icons.smartphone_rounded);

  const _CardAspect(this.label, this.ratio, this.icon);
  final String label;
  final double ratio;
  final IconData icon;
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
  ('ميرزا', AppFonts.mirza),
  ('رُودو', AppFonts.ruwudu),
  ('جلزار', AppFonts.gulzar),
  ('كاتِبة', AppFonts.katibeh),
  ('الرقعة', AppFonts.ruqaa),
  ('المخطوطات', AppFonts.amiriQuran),
];

/// Redesigned 4-Tab High-Resolution Poetry Card Designer.
///
/// Cleanly separates Template, Font & Size, Aspect & Layout, and Elements into
/// dedicated tabbed panels for serene, effortless card crafting.
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

  int _inspectorTab = 0; // 0: القالب | 1: الخط | 2: المقاس | 3: العناصر
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
        title: const Text('تصميم بطاقة شعرية'),
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

          // Organized 4-Tab Studio Dock
          Container(
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              border: Border(
                top: BorderSide(color: p.ornament.withValues(alpha: 0.4)),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dedicated Tab Selector
                    Row(
                      children: [
                        _StudioTab(
                          icon: Icons.palette_outlined,
                          label: 'القالب',
                          active: _inspectorTab == 0,
                          onTap: () => setState(() => _inspectorTab = 0),
                        ),
                        _StudioTab(
                          icon: Icons.font_download_outlined,
                          label: 'الخط',
                          active: _inspectorTab == 1,
                          onTap: () => setState(() => _inspectorTab = 1),
                        ),
                        _StudioTab(
                          icon: Icons.aspect_ratio_rounded,
                          label: 'المقاس',
                          active: _inspectorTab == 2,
                          onTap: () => setState(() => _inspectorTab = 2),
                        ),
                        _StudioTab(
                          icon: Icons.tune_rounded,
                          label: 'العناصر',
                          active: _inspectorTab == 3,
                          onTap: () => setState(() => _inspectorTab = 3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tab Panel Content (Fixed sleek height for zero layout jump)
                    SizedBox(
                      height: 98,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: switch (_inspectorTab) {
                          0 => _buildTemplatesTab(),
                          1 => _buildFontsTab(context),
                          2 => _buildAspectTab(context),
                          _ => _buildElementsTab(),
                        },
                      ),
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

  Widget _buildTemplatesTab() {
    return ListView.separated(
      key: const ValueKey('tpl_tab'),
      scrollDirection: Axis.horizontal,
      itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final t = _templates[i];
        final sel = i == _templateIndex;
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _templateIndex = i);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 104,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [t.bgTop, t.bgBottom],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? t.accent : t.border,
                width: sel ? 2.2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'أبجد',
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontsTab(BuildContext context) {
    final p = context.palette;
    return Column(
      key: const ValueKey('font_tab'),
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cardFonts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _cardFonts[i];
              final sel = _fontFamily == f.$2;
              return ChoiceChip(
                selected: sel,
                label: Text(
                  f.$1,
                  style: TextStyle(fontFamily: f.$2, fontSize: 15),
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _fontFamily = f.$2);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('حجم الخط', style: Theme.of(context).textTheme.labelMedium),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 14,
                max: 30,
                activeColor: p.accent,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
            Text(
              '${_fontSize.round()}',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAspectTab(BuildContext context) {
    final p = context.palette;
    return Column(
      key: const ValueKey('aspect_tab'),
      children: [
        Row(
          children: _CardAspect.values.map((a) {
            final sel = _aspect == a;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _aspect = a);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? p.accentSoft : p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? p.accent : p.hairline,
                        width: sel ? 1.5 : 0.9,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          a.icon,
                          size: 18,
                          color: sel ? p.accent : p.inkMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          a.label,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 11.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? p.accent : p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              selected: _staggered,
              label: const Text('شطران متدرّجان'),
              onSelected: (_) => setState(() => _staggered = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              selected: !_staggered,
              label: const Text('شطران متقابلان'),
              onSelected: (_) => setState(() => _staggered = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildElementsTab() {
    return Center(
      key: const ValueKey('elem_tab'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          FilterChip(
            selected: _showDiacritics,
            label: const Text('إظهار التشكيل'),
            onSelected: (v) => setState(() => _showDiacritics = v),
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
    );
  }
}

class _StudioTab extends StatelessWidget {
  const _StudioTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? p.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? p.accent.withValues(alpha: 0.35) : p.hairline,
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? p.accent : p.inkMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? p.accent : p.inkMuted,
                ),
              ),
            ],
          ),
        ),
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
