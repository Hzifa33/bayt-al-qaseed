import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poem.dart';
import '../../../data/models/poet.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import '../reader/poem_reader_screen.dart';

class PoetDetailScreen extends ConsumerStatefulWidget {
  const PoetDetailScreen({super.key, required this.poetId});

  final int poetId;

  @override
  ConsumerState<PoetDetailScreen> createState() => _PoetDetailScreenState();
}

class _PoetDetailScreenState extends ConsumerState<PoetDetailScreen> {
  PoemSortBy _sortBy = PoemSortBy.rhyme;
  int? _selectedMeterId;
  int? _selectedRhymeId;
  String _titleFilter = '';
  bool _bioExpanded = false;

  late final Poet? _poet;
  late final List<Meter> _meters;
  late final List<Rhyme> _rhymes;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(poetryRepositoryProvider);
    _poet = repo.getPoetById(widget.poetId);
    _meters = repo.getMetersForPoet(widget.poetId);
    _rhymes = repo.getRhymesForPoet(widget.poetId);
  }

  @override
  Widget build(BuildContext context) {
    final poet = _poet;
    if (poet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateView(
          icon: Icons.error_outline,
          title: 'تعذّر العثور على الشاعر',
          subtitle: 'ربما لم يعد هذا السجل متاحاً.',
        ),
      );
    }

    final p = context.palette;
    final userData = ref.watch(userDataProvider);
    final isFavPoet = userData.favoritePoetIds.contains(poet.id);
    final poems = ref
        .read(poetryRepositoryProvider)
        .getPoemsForPoet(
          poet.id,
          sortBy: _sortBy,
          meterId: _selectedMeterId,
          rhymeId: _selectedRhymeId,
          titleFilter: _titleFilter,
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(poet.namePlain),
            actions: [
              IconButton(
                tooltip: isFavPoet
                    ? 'إزالة الشاعر من المفضلة'
                    : 'حفظ الشاعر في المفضلة',
                onPressed: () {
                  final added = ref
                      .read(userDataProvider.notifier)
                      .toggleFavoritePoet(poet.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added
                            ? 'أُضيف ${poet.namePlain} إلى الشعراء المفضلين'
                            : 'أُزيل ${poet.namePlain} من المفضلة',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  isFavPoet
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavPoet ? p.accent : p.ink,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Poet Biography Editorial Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poet.name,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaBadge(text: 'العصر ${poet.eraName}'),
                        if (poet.formattedDates.isNotEmpty)
                          _MetaBadge(text: poet.formattedDates),
                        _MetaBadge(
                          text:
                              '${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
                        ),
                        _MetaBadge(
                          text:
                              '${ArabicNormalizer.toArabicNumber(poet.verseCount)} بيتاً',
                        ),
                      ],
                    ),
                    if (poet.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        poet.bio,
                        maxLines: _bioExpanded ? null : 3,
                        overflow: _bioExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: p.inkMuted, height: 1.75),
                      ),
                      if (poet.bio.length > 140)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _bioExpanded = !_bioExpanded),
                            child: Text(
                              _bioExpanded
                                  ? 'إخفاء الترجمة'
                                  : 'قراءة الترجمة كاملة',
                              style: TextStyle(color: p.accent),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Smart Filter & Sort Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _titleFilter = v),
                    decoration: InputDecoration(
                      hintText: 'ابحث في مطالع قصائد ${poet.namePlain}…',
                      prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sort selector + Meter & Rhyme dropdown pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PopupMenuButton<PoemSortBy>(
                          initialValue: _sortBy,
                          onSelected: (v) => setState(() => _sortBy = v),
                          itemBuilder: (_) => PoemSortBy.values
                              .map(
                                (s) => PopupMenuItem(
                                  value: s,
                                  child: Text(s.label),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: p.accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ترتيب: ${_sortBy.label}',
                                  style: TextStyle(
                                    fontFamily: AppFonts.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_meters.length > 1)
                          _FilterDropdownPill(
                            label: _selectedMeterId == null
                                ? 'كل البحور'
                                : 'بحر ${_meters.firstWhere((m) => m.id == _selectedMeterId).name}',
                            isActive: _selectedMeterId != null,
                            onTap: () => _pickMeter(context),
                          ),
                        const SizedBox(width: 8),
                        if (_rhymes.length > 1)
                          _FilterDropdownPill(
                            label: _selectedRhymeId == null
                                ? 'كل القوافي'
                                : 'قافية ${_rhymes.firstWhere((r) => r.id == _selectedRhymeId).name}',
                            isActive: _selectedRhymeId != null,
                            onTap: () => _pickRhyme(context),
                          ),
                        if (_selectedMeterId != null ||
                            _selectedRhymeId != null) ...[
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('مسح الفلاتر'),
                            onPressed: () => setState(() {
                              _selectedMeterId = null;
                              _selectedRhymeId = null;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Count indicator
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'عرض ${ArabicNormalizer.toArabicNumber(poems.length)} قصيدة',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),

          // Poems List
          if (poems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.filter_list_off_rounded,
                title: 'لا توجد قصائد مطابقة للتصفية',
                subtitle: 'جرّب تغيير البحر أو حرف الرويّ أو عبارة التصفية.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              sliver: SliverList.separated(
                itemCount: poems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final poem = poems[i];
                  final isFav = userData.favoritePoemIds.contains(poem.id);
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoemReaderScreen(poemId: poem.id),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.hairline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: p.hairline),
                            ),
                            child: Text(
                              poem.rhymeName.length <= 2 ? poem.rhymeName : '۞',
                              style: TextStyle(
                                fontFamily: AppFonts.ruqaa,
                                fontSize: 16,
                                color: p.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  poem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.scheherazade,
                                    fontSize: 20,
                                    color: p.ink,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'بحر ${poem.meterName}  •  الرويّ (${poem.rhymeName})  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          if (isFav)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.bookmark_rounded,
                                size: 18,
                                color: p.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickMeter(BuildContext context) async {
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => _OptionSheet<Meter>(
        title: 'تصفية حسب البحر العروضي',
        items: _meters,
        selectedId: _selectedMeterId,
        idOf: (m) => m.id,
        labelOf: (m) =>
            'بحر ${m.name} (${ArabicNormalizer.toArabicNumber(m.poemCount)})',
      ),
    );
    if (chosen == -1) {
      setState(() => _selectedMeterId = null);
    } else if (chosen != null) {
      setState(() => _selectedMeterId = chosen);
    }
  }

  Future<void> _pickRhyme(BuildContext context) async {
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => _OptionSheet<Rhyme>(
        title: 'تصفية حسب حرف الرويّ',
        items: _rhymes,
        selectedId: _selectedRhymeId,
        idOf: (r) => r.id,
        labelOf: (r) =>
            'قافية (${r.name}) — ${ArabicNormalizer.toArabicNumber(r.poemCount)} قصيدة',
      ),
    );
    if (chosen == -1) {
      setState(() => _selectedRhymeId = null);
    } else if (chosen != null) {
      setState(() => _selectedRhymeId = chosen);
    }
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.hairline),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.ink),
      ),
    );
  }
}

class _FilterDropdownPill extends StatelessWidget {
  const _FilterDropdownPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? p.accentSoft : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? p.accent.withValues(alpha: 0.45) : p.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? p.accent : p.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? p.accent : p.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.labelOf,
  });

  final String title;
  final List<T> items;
  final int? selectedId;
  final int Function(T) idOf;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(-1),
                  child: Text('الكل', style: TextStyle(color: p.accent)),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final id = idOf(item);
                final selected = id == selectedId;
                return ListTile(
                  title: Text(labelOf(item)),
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: p.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
