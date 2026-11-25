import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poem.dart';
import '../../providers/database_providers.dart';
import '../reader/poem_reader_screen.dart';

Color _feelingAccent(String rootSlug, Color fallback) => switch (rootSlug) {
  'alsurur' => const Color(0xFFB37A2A),
  'alhuzn' => const Color(0xFF476985),
  'altaajjub' => const Color(0xFF6B538C),
  'alghadab' => const Color(0xFFA64B3C),
  'alkhawf' => const Color(0xFF3E6E64),
  'alishmizaz' => const Color(0xFF7B6B43),
  'aldiq' => const Color(0xFF6B5B53),
  _ => fallback,
};

IconData _feelingIcon(String rootSlug) => switch (rootSlug) {
  'alsurur' => Icons.wb_sunny_outlined,
  'alhuzn' => Icons.water_drop_outlined,
  'altaajjub' => Icons.auto_awesome_outlined,
  'alghadab' => Icons.local_fire_department_outlined,
  'alkhawf' => Icons.shield_outlined,
  'alishmizaz' => Icons.visibility_off_outlined,
  'aldiq' => Icons.cloud_outlined,
  _ => Icons.psychology_outlined,
};

/// Hierarchical Arabic Poetry Feelings Explorer (7 root emotions -> 127 nuances).
class FeelingsExplorerView extends StatelessWidget {
  const FeelingsExplorerView({super.key, required this.roots});

  final List<Feeling> roots;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 102),
      itemCount: roots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final root = roots[i];
        final accent = _feelingAccent(root.slug, p.accent);
        final subCount = root.children.fold<int>(
          root.children.length,
          (acc, c) => acc + c.children.length,
        );

        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            BaytNav.pushEditorial(
              context,
              FeelingDetailScreen(rootFeeling: root),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _feelingIcon(root.slug),
                        color: accent,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            root.name,
                            style: TextStyle(
                              fontFamily: AppFonts.ruqaa,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            '${ArabicNormalizer.toArabicNumber(subCount)} تقسيماً فرعياً  •  ${ArabicNormalizer.toArabicNumber(root.verseCount)} بيتاً',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: p.inkMuted,
                    ),
                  ],
                ),
                if (root.children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: root.children.take(6).map((child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.24),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          child.name,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: p.ink, fontSize: 11),
                        ),
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
}

/// Interactive detail screen for a root feeling with 2nd & 3rd-level branches and matching poems.
class FeelingDetailScreen extends ConsumerStatefulWidget {
  const FeelingDetailScreen({super.key, required this.rootFeeling});

  final Feeling rootFeeling;

  @override
  ConsumerState<FeelingDetailScreen> createState() =>
      _FeelingDetailScreenState();
}

class _FeelingDetailScreenState extends ConsumerState<FeelingDetailScreen> {
  Feeling? _selectedBranch;
  late Feeling _activeFeeling;
  final List<PoemSummary> _poems = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _activeFeeling = widget.rootFeeling;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadPoems();
    });
  }

  void _selectFeeling(Feeling target, {Feeling? branch}) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedBranch = branch;
      _activeFeeling = target;
      _poems.clear();
      _offset = 0;
      _hasMore = true;
      _loading = true;
    });
    _loadMore();
  }

  void _reloadPoems() {
    _poems.clear();
    _offset = 0;
    _hasMore = true;
    _loadMore();
  }

  void _loadMore() {
    if (!_hasMore) return;
    final batch = ref
        .read(poetryRepositoryProvider)
        .getPoemsByFeeling(
          _activeFeeling,
          rootSlug: widget.rootFeeling.slug,
          limit: 50,
          offset: _offset,
        );
    setState(() {
      _poems.addAll(batch);
      _offset += batch.length;
      _loading = false;
      if (batch.length < 50) _hasMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = _feelingAccent(widget.rootFeeling.slug, p.accent);
    final branches = widget.rootFeeling.children;
    final subLeaves = _selectedBranch?.children ?? const <Feeling>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مشاعر ${widget.rootFeeling.name}',
              style: TextStyle(
                fontFamily: AppFonts.ruqaa,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.25,
              ),
            ),
            Text(
              _activeFeeling.slug == widget.rootFeeling.slug
                  ? 'جميع التفرعات (${ArabicNormalizer.toArabicNumber(widget.rootFeeling.verseCount)} بيتاً)'
                  : '${_activeFeeling.name}  •  ${ArabicNormalizer.toArabicNumber(_activeFeeling.verseCount)} بيتاً',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontSize: 10.5, color: accent),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 2nd-level branches bar
          if (branches.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      selected: _activeFeeling.slug == widget.rootFeeling.slug,
                      visualDensity: VisualDensity.compact,
                      label: Text('الكل (${widget.rootFeeling.name})'),
                      onSelected: (_) =>
                          _selectFeeling(widget.rootFeeling, branch: null),
                    ),
                  ),
                  ...branches.map((br) {
                    final selected = _selectedBranch?.slug == br.slug;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        label: Text(br.name),
                        onSelected: (_) => _selectFeeling(br, branch: br),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // 3rd-level nuances bar (when a branch is chosen)
          if (subLeaves.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                children: subLeaves.map((leaf) {
                  final selected = _activeFeeling.slug == leaf.slug;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      selected: selected,
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${leaf.name} (${ArabicNormalizer.toArabicNumber(leaf.verseCount)})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onSelected: (_) =>
                          _selectFeeling(leaf, branch: _selectedBranch),
                    ),
                  );
                }).toList(),
              ),
            ),

          Expanded(
            child: AnimatedSwitcher(
              duration: BaytMotion.popover,
              child: _loading
                  ? Center(
                      key: const ValueKey('loading'),
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 2.2,
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey(_activeFeeling.slug),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: _poems.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        if (i >= _poems.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: _loadMore,
                                child: const Text('عرض مزيدٍ من القصائد'),
                              ),
                            ),
                          );
                        }
                        final poem = _poems[i];
                        return InkWell(
                          onTap: () => BaytNav.pushDrop(
                            context,
                            PoemReaderScreen(poemId: poem.id),
                          ),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: p.hairline,
                                width: 0.85,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  poem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.scheherazade,
                                    fontSize: 17.5,
                                    color: p.ink,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${poem.poetName}  •  ${poem.eraName}  •  ${poem.meterName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: p.inkMuted),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيت',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: accent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
