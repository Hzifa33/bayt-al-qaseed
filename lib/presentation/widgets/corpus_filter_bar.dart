import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/arabic_normalizer.dart';
import '../../data/models/era.dart';
import '../../data/models/meter.dart';
import '../providers/app_providers.dart';

/// Immutable multi-facet filter state shared by Themes, Meters, and Feelings screens.
class CorpusFilterState {
  const CorpusFilterState({
    this.eraId,
    this.meterId,
    this.rhymeId,
    this.themeId,
  });

  final int? eraId;
  final int? meterId;
  final int? rhymeId;
  final int? themeId;

  bool get isEmpty =>
      eraId == null && meterId == null && rhymeId == null && themeId == null;

  int get activeCount =>
      (eraId != null ? 1 : 0) +
      (meterId != null ? 1 : 0) +
      (rhymeId != null ? 1 : 0) +
      (themeId != null ? 1 : 0);

  CorpusFilterState copyWith({
    int? eraId,
    bool clearEra = false,
    int? meterId,
    bool clearMeter = false,
    int? rhymeId,
    bool clearRhyme = false,
    int? themeId,
    bool clearTheme = false,
  }) {
    return CorpusFilterState(
      eraId: clearEra ? null : (eraId ?? this.eraId),
      meterId: clearMeter ? null : (meterId ?? this.meterId),
      rhymeId: clearRhyme ? null : (rhymeId ?? this.rhymeId),
      themeId: clearTheme ? null : (themeId ?? this.themeId),
    );
  }
}

/// Compact, sleek filter strip (العصر · البحر · حرف الروي · الغرض) with
/// instant bottom-sheet pickers and a 1-tap Arabic rhyme-letter grid.
class CorpusFilterBar extends ConsumerWidget {
  const CorpusFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.showEra = true,
    this.showMeter = true,
    this.showRhyme = true,
    this.showTheme = false,
    this.accentColor,
  });

  final CorpusFilterState filter;
  final ValueChanged<CorpusFilterState> onChanged;
  final bool showEra;
  final bool showMeter;
  final bool showRhyme;
  final bool showTheme;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final accent = accentColor ?? p.accent;
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final rhymes = ref.watch(rhymesProvider);
    final themes = ref.watch(themesProvider);

    final selectedEra = filter.eraId == null
        ? null
        : eras.where((e) => e.id == filter.eraId).firstOrNull;
    final selectedMeter = filter.meterId == null
        ? null
        : meters.where((m) => m.id == filter.meterId).firstOrNull;
    final selectedRhyme = filter.rhymeId == null
        ? null
        : rhymes.where((r) => r.id == filter.rhymeId).firstOrNull;
    final selectedTheme = filter.themeId == null
        ? null
        : themes.where((t) => t.id == filter.themeId).firstOrNull;

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [
          if (!filter.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(const CorpusFilterState());
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 0.85,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'مسح',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (showEra && eras.isNotEmpty)
            _FilterPill(
              icon: Icons.hourglass_bottom_rounded,
              label: selectedEra != null
                  ? 'العصر ${selectedEra.name}'
                  : 'العصر',
              active: selectedEra != null,
              accent: accent,
              onTap: () => _pickEra(context, eras, accent),
            ),
          if (showMeter && meters.isNotEmpty)
            _FilterPill(
              icon: Icons.waves_rounded,
              label: selectedMeter != null
                  ? 'بحر ${selectedMeter.name}'
                  : 'البحر',
              active: selectedMeter != null,
              accent: accent,
              onTap: () => _pickMeter(context, meters, accent),
            ),
          if (showRhyme && rhymes.isNotEmpty)
            _FilterPill(
              icon: Icons.abc_rounded,
              label: selectedRhyme != null
                  ? 'الرويّ (${selectedRhyme.letter.isNotEmpty && selectedRhyme.letter.length <= 2 ? selectedRhyme.letter : selectedRhyme.name})'
                  : 'حرف الرويّ',
              active: selectedRhyme != null,
              accent: accent,
              onTap: () => _pickRhyme(context, rhymes, accent),
            ),
          if (showTheme && themes.isNotEmpty)
            _FilterPill(
              icon: Icons.category_outlined,
              label: selectedTheme != null
                  ? 'غرض ${selectedTheme.name}'
                  : 'الغرض',
              active: selectedTheme != null,
              accent: accent,
              onTap: () => _pickTheme(context, themes, accent),
            ),
        ],
      ),
    );
  }

  void _pickEra(BuildContext context, List<Era> eras, Color accent) {
    HapticFeedback.selectionClick();
    _showListSheet<Era>(
      context: context,
      title: 'تصفية حسب العصر',
      items: eras,
      selectedId: filter.eraId,
      idOf: (e) => e.id,
      titleOf: (e) => 'العصر ${e.name}',
      subtitleOf: (e) =>
          '${ArabicNormalizer.toArabicNumber(e.poemCount)} قصيدة',
      accent: accent,
      onClear: () => onChanged(filter.copyWith(clearEra: true)),
      onSelect: (e) => onChanged(filter.copyWith(eraId: e.id)),
    );
  }

  void _pickMeter(BuildContext context, List<Meter> meters, Color accent) {
    HapticFeedback.selectionClick();
    _showListSheet<Meter>(
      context: context,
      title: 'تصفية حسب البحر العروضي',
      items: meters,
      selectedId: filter.meterId,
      idOf: (m) => m.id,
      titleOf: (m) => 'بحر ${m.name}',
      subtitleOf: (m) =>
          '${ArabicNormalizer.toArabicNumber(m.poemCount)} قصيدة',
      accent: accent,
      onClear: () => onChanged(filter.copyWith(clearMeter: true)),
      onSelect: (m) => onChanged(filter.copyWith(meterId: m.id)),
    );
  }

  void _pickTheme(
    BuildContext context,
    List<ThemeCategory> themes,
    Color accent,
  ) {
    HapticFeedback.selectionClick();
    _showListSheet<ThemeCategory>(
      context: context,
      title: 'تصفية حسب الغرض الشعري',
      items: themes,
      selectedId: filter.themeId,
      idOf: (t) => t.id,
      titleOf: (t) => t.name,
      subtitleOf: (t) =>
          '${ArabicNormalizer.toArabicNumber(t.poemCount)} قصيدة',
      accent: accent,
      onClear: () => onChanged(filter.copyWith(clearTheme: true)),
      onSelect: (t) => onChanged(filter.copyWith(themeId: t.id)),
    );
  }

  void _pickRhyme(BuildContext context, List<Rhyme> rhymes, Color accent) {
    HapticFeedback.selectionClick();
    final p = context.palette;
    final singleLetters = rhymes
        .where((r) => r.letter.isNotEmpty && r.letter.length <= 2)
        .toList();
    final others = rhymes
        .where((r) => r.letter.isEmpty || r.letter.length > 2)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'تصفية حسب حرف الرويّ',
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const Spacer(),
                    if (filter.rhymeId != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onChanged(filter.copyWith(clearRhyme: true));
                        },
                        child: Text('الكل', style: TextStyle(color: accent)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: singleLetters.map((r) {
                    final selected = filter.rhymeId == r.id;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        if (selected) {
                          onChanged(filter.copyWith(clearRhyme: true));
                        } else {
                          onChanged(filter.copyWith(rhymeId: r.id));
                        }
                      },
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        width: 44,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? accent : p.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: selected ? accent : p.hairline,
                            width: 0.9,
                          ),
                        ),
                        child: Text(
                          r.letter,
                          style: TextStyle(
                            fontFamily: AppFonts.ruqaa,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Theme.of(ctx).colorScheme.onPrimary
                                : p.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: others.map((r) {
                      final selected = filter.rhymeId == r.id;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(r.name),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          if (selected) {
                            onChanged(filter.copyWith(clearRhyme: true));
                          } else {
                            onChanged(filter.copyWith(rhymeId: r.id));
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showListSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required int? selectedId,
    required int Function(T) idOf,
    required String Function(T) titleOf,
    required String Function(T) subtitleOf,
    required Color accent,
    required VoidCallback onClear,
    required ValueChanged<T> onSelect,
  }) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const Spacer(),
                      if (selectedId != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onClear();
                          },
                          child: Text('الكل', style: TextStyle(color: accent)),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.hairline),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final selected = idOf(item) == selectedId;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: selected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        title: Text(
                          titleOf(item),
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? accent : p.ink,
                          ),
                        ),
                        trailing: Text(
                          subtitleOf(item),
                          style: Theme.of(ctx).textTheme.labelSmall
                              ?.copyWith(color: p.inkMuted),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          if (selected) {
                            onClear();
                          } else {
                            onSelect(item);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.14) : p.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? accent : p.hairline,
              width: active ? 1.0 : 0.85,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.5, color: active ? accent : p.inkMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? accent : p.ink,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: active ? accent : p.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
