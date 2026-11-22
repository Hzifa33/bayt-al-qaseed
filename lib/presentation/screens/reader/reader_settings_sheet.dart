import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../data/models/reader_settings.dart';
import '../../providers/settings_provider.dart';

/// Compact, live, non-obstructive typography & reading dock.
///
/// Renders docked gently over the bottom third of the reader WITHOUT a dark
/// barrier so the reader watches the poem update live in real time while
/// switching fonts, font sizes, staggered/side-by-side layout, themes,
/// diacritics, and verse numbering.
class LiveTypographyPanel extends ConsumerStatefulWidget {
  const LiveTypographyPanel({
    super.key,
    required this.poemHasDiacritics,
    required this.onClose,
  });

  final bool poemHasDiacritics;
  final VoidCallback onClose;

  @override
  ConsumerState<LiveTypographyPanel> createState() =>
      _LiveTypographyPanelState();
}

class _LiveTypographyPanelState extends ConsumerState<LiveTypographyPanel> {
  int _tab = 0; // 0: الخط والحجم | 1: التنسيق | 2: الألوان

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: p.ornament.withValues(alpha: 0.45),
            width: 1.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Compact Header with Tab Switcher + Close
              Row(
                children: [
                  _MiniTab(
                    label: 'الخط والحجم',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 6),
                  _MiniTab(
                    label: 'التنسيق',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 6),
                  _MiniTab(
                    label: 'الألوان',
                    active: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'إغلاق',
                    onPressed: widget.onClose,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: p.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_tab) {
                  0 => _buildFontAndSizeTab(context, settings, notifier),
                  1 => _buildLayoutTab(context, settings, notifier),
                  _ => _buildThemeTab(context, settings, notifier),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontAndSizeTab(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final p = context.palette;
    return Column(
      key: const ValueKey('font_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PoetryFontOption.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final font = PoetryFontOption.values[i];
              final sel = settings.poetryFont == font;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setPoetryFont(font);
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? p.accentSoft : p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? p.accent : p.hairline,
                      width: sel ? 1.4 : 0.9,
                    ),
                  ),
                  child: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 18 * font.scaleMultiplier.clamp(0.95, 1.1),
                      color: sel ? p.accent : p.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('أ', style: TextStyle(fontSize: 13, color: p.inkMuted)),
            Expanded(
              child: Slider(
                value: settings.fontSize,
                min: 15,
                max: 30,
                divisions: 15,
                activeColor: p.accent,
                onChanged: notifier.setFontSize,
              ),
            ),
            Text('أ', style: TextStyle(fontSize: 22, color: p.ink)),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '${settings.fontSize.round()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayoutTab(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final p = context.palette;
    return Column(
      key: const ValueKey('layout_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: VerseLayoutStyle.values.map((layout) {
            final sel = settings.verseLayout == layout;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    notifier.setVerseLayout(layout);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? p.accentSoft : p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? p.accent : p.hairline,
                        width: sel ? 1.4 : 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          layout == VerseLayoutStyle.staggered
                              ? Icons.format_align_center_rounded
                              : Icons.view_column_outlined,
                          size: 17,
                          color: sel ? p.accent : p.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          layout.displayName,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12.5,
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.poemHasDiacritics)
              FilterChip(
                selected: settings.showDiacritics,
                avatar: Icon(
                  Icons.spellcheck_rounded,
                  size: 16,
                  color: settings.showDiacritics ? p.accent : p.inkMuted,
                ),
                label: const Text('إظهار التشكيل'),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  notifier.toggleDiacritics();
                },
              ),
            FilterChip(
              selected: settings.showVerseNumbers,
              avatar: Icon(
                Icons.format_list_numbered_rtl_rounded,
                size: 16,
                color: settings.showVerseNumbers ? p.accent : p.inkMuted,
              ),
              label: const Text('ترقيم الأبيات'),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                notifier.toggleVerseNumbers();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeTab(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final p = context.palette;
    return Row(
      key: const ValueKey('theme_tab'),
      children: ReadingThemeMode.values.map((mode) {
        final selected = settings.themeMode == mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                notifier.setThemeMode(mode);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: mode == ReadingThemeMode.materialYou
                      ? p.surface
                      : mode.previewBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? p.accent : p.hairline,
                    width: selected ? 2.0 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mode == ReadingThemeMode.materialYou)
                      MaterialYouIcon(
                        size: 20,
                        filled: selected,
                        color: selected ? p.accent : p.ink,
                      )
                    else
                      Text(
                        'أبجد',
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: mode.previewInk,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      mode.displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 10.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: mode == ReadingThemeMode.materialYou
                            ? p.ink
                            : mode.previewInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MiniTab extends StatelessWidget {
  const _MiniTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? p.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? p.accent.withValues(alpha: 0.4) : p.hairline,
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? p.accent : p.inkMuted,
          ),
        ),
      ),
    );
  }
}
