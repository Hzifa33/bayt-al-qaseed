import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/reader_settings.dart';
import '../../providers/settings_provider.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key, this.poemHasDiacritics = true});

  final bool poemHasDiacritics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.hairline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'مظهر القراءة والخط العربي',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),

            // 1. Reading Theme Selector
            Text('وضع القراءة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: ReadingThemeMode.values.map((mode) {
                final selected = settings.themeMode == mode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => notifier.setThemeMode(mode),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: mode.previewBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? mode.previewAccent : p.hairline,
                            width: selected ? 2.2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'أبجد',
                              style: TextStyle(
                                fontFamily: AppFonts.ruqaa,
                                fontSize: 18,
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
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: mode.previewInk,
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
            const SizedBox(height: 20),

            // 2. Poetry Font Selector
            Text('خط القصيدة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: PoetryFontOption.values.map((font) {
                final selected = settings.poetryFont == font;
                return InkWell(
                  onTap: () => notifier.setPoetryFont(font),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? p.accentSoft : p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? p.accent : p.hairline,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          font.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: font.family,
                            fontSize:
                                18 * font.scaleMultiplier.clamp(0.95, 1.12),
                            color: selected ? p.accent : p.ink,
                            height: 1.35,
                          ),
                        ),
                        Text(
                          font.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Font Size Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('حجم الخط', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${settings.fontSize.round()}',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
              ],
            ),
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
              ],
            ),
            const SizedBox(height: 12),

            // 4. Verse Layout Switcher
            Text(
              'تنسيق الشطرين',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            SegmentedButton<VerseLayoutStyle>(
              segments: VerseLayoutStyle.values
                  .map(
                    (l) => ButtonSegment<VerseLayoutStyle>(
                      value: l,
                      label: Text(l.displayName),
                      icon: Icon(
                        l == VerseLayoutStyle.sideBySide
                            ? Icons.view_column_outlined
                            : Icons.format_align_center_rounded,
                        size: 18,
                      ),
                    ),
                  )
                  .toList(),
              selected: {settings.verseLayout},
              onSelectionChanged: (set) => notifier.setVerseLayout(set.first),
            ),
            const SizedBox(height: 14),

            // 5. Diacritics & Numbering Toggles
            if (poemHasDiacritics)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار التشكيل (الحركات)'),
                subtitle: const Text('إخفاء أو إظهار الحركات الإعرابية'),
                value: settings.showDiacritics,
                onChanged: (_) => notifier.toggleDiacritics(),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('ترقيم الأبيات'),
              subtitle: const Text('إظهار رقم كل بيت بمحاذاة الهامش'),
              value: settings.showVerseNumbers,
              onChanged: (_) => notifier.toggleVerseNumbers(),
            ),
          ],
        ),
      ),
    );
  }
}
