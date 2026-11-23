import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poem.dart';
import '../../../data/models/poet.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import '../reader/poem_reader_screen.dart';
import 'poet_bio_screen.dart';

class _PoemListEntry {
  const _PoemListEntry.header(this.sectionTitle, this.shortLabel, this.count)
    : poem = null;
  const _PoemListEntry.poem(this.poem)
    : sectionTitle = null,
      shortLabel = null,
      count = 0;

  final String? sectionTitle;
  final String? shortLabel;
  final int count;
  final PoemSummary? poem;

  bool get isHeader => poem == null;
}

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
  bool _searchOpen = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  Poet? _poet;
  List<Meter> _meters = const [];
  List<Rhyme> _rhymes = const [];
  List<PoemSummary> _poems = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Defer DB load by 1 microtask so the page transition runs smoothly first!
    Future.microtask(_loadInitial);
  }

  void _loadInitial() {
    if (!mounted) return;
    final repo = ref.read(poetryRepositoryProvider);
    final poet = repo.getPoetById(widget.poetId);
    final meters = poet != null
        ? repo.getMetersForPoet(widget.poetId)
        : <Meter>[];
    final rhymes = poet != null
        ? repo.getRhymesForPoet(widget.poetId)
        : <Rhyme>[];
    final poems = poet != null
        ? repo.getPoemsForPoet(widget.poetId, sortBy: _sortBy)
        : <PoemSummary>[];
    setState(() {
      _poet = poet;
      _meters = meters;
      _rhymes = rhymes;
      _poems = poems;
      _loading = false;
    });
  }

  void _reloadPoems() {
    if (_poet == null) return;
    final poems = ref
        .read(poetryRepositoryProvider)
        .getPoemsForPoet(
          _poet!.id,
          sortBy: _sortBy,
          meterId: _selectedMeterId,
          rhymeId: _selectedRhymeId,
          titleFilter: _titleFilter,
        );
    setState(() => _poems = poems);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  void _openSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    final hadQuery = _titleFilter.isNotEmpty;
    _searchCtrl.clear();
    setState(() {
      _searchOpen = false;
      _titleFilter = '';
    });
    if (hadQuery) _reloadPoems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Groups poems into visual sections with headers + offset table for the Contacts-style fast scroller.
  (List<_PoemListEntry>, List<String>, List<double>) _buildSectionedEntries(
    List<PoemSummary> poems,
  ) {
    const headerHeight = 38.0;
    const itemHeight = 72.0;

    final entries = <_PoemListEntry>[];
    final sectionLabels = <String>[];
    final sectionOffsets = <double>[];

    final useSections =
        _sortBy == PoemSortBy.rhyme ||
        _sortBy == PoemSortBy.meter ||
        _sortBy == PoemSortBy.alphabetical;

    if (!useSections) {
      for (final poem in poems) {
        entries.add(_PoemListEntry.poem(poem));
      }
      return (entries, sectionLabels, sectionOffsets);
    }

    String keyOf(PoemSummary poem) {
      switch (_sortBy) {
        case PoemSortBy.rhyme:
          return poem.rhymeName;
        case PoemSortBy.meter:
          return poem.meterName;
        case PoemSortBy.alphabetical:
          final norm = ArabicNormalizer.normalize(poem.title);
          return norm.isEmpty ? 'أ' : norm.substring(0, 1);
        default:
          return '';
      }
    }

    String titleOf(String key) {
      switch (_sortBy) {
        case PoemSortBy.rhyme:
          return key.length <= 2 ? 'قافيةُ ($key)' : 'قافية: $key';
        case PoemSortBy.meter:
          return 'بحرُ $key';
        case PoemSortBy.alphabetical:
          return 'حرفُ ($key)';
        default:
          return key;
      }
    }

    final counts = <String, int>{};
    for (final poem in poems) {
      final k = keyOf(poem);
      counts[k] = (counts[k] ?? 0) + 1;
    }

    String? currentKey;
    double offset = 0.0;
    for (final poem in poems) {
      final k = keyOf(poem);
      if (k != currentKey) {
        currentKey = k;
        sectionLabels.add(k);
        sectionOffsets.add(offset);
        entries.add(_PoemListEntry.header(titleOf(k), k, counts[k] ?? 0));
        offset += headerHeight;
      }
      entries.add(_PoemListEntry.poem(poem));
      offset += itemHeight;
    }

    return (entries, sectionLabels, sectionOffsets);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ديوان الشاعر')),
        body: Center(
          child: CircularProgressIndicator(color: p.accent, strokeWidth: 2.2),
        ),
      );
    }

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

    final userData = ref.watch(userDataProvider);
    final isFavPoet = userData.favoritePoetIds.contains(poet.id);
    final (entries, sectionLabels, sectionOffsets) = _buildSectionedEntries(
      _poems,
    );

    return PopScope(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchOpen) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: AnimatedSwitcher(
            duration: BaytMotion.popover,
            switchInCurve: BaytMotion.easeOut,
            switchOutCurve: BaytMotion.exit,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.04, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _searchOpen
                ? TextField(
                    key: const ValueKey('poet_search_field'),
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) {
                      _titleFilter = v;
                      _reloadPoems();
                    },
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'ابحث في مطالع قصائد ${poet.namePlain}…',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  )
                : Row(
                    key: const ValueKey('poet_title_row'),
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              poet.namePlain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.ruqaa,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                                height: 1.25,
                              ),
                            ),
                            Text(
                              'العصر ${poet.eraName}  •  ${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: 10.5,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            if (_searchOpen)
              IconButton(
                tooltip: 'إغلاق البحث',
                onPressed: _closeSearch,
                icon: const BaytIconMorph(
                  icon: Icon(Icons.close_rounded, key: ValueKey('close_s')),
                ),
              )
            else ...[
              // Progressive Disclosure: Poet Biography & Profile Icon right beside name
              IconButton(
                tooltip: 'سيرة الشاعر وبياناته',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  BaytNav.pushEditorial(
                    context,
                    PoetBioScreen(poet: poet, meters: _meters),
                  );
                },
                icon: Icon(Icons.info_outline_rounded, color: p.accent),
              ),
              // On-demand Collapsible Search Icon
              IconButton(
                tooltip: 'بحث في قصائد الشاعر',
                onPressed: _openSearch,
                icon: const BaytIconMorph(
                  icon: Icon(Icons.search_rounded, key: ValueKey('open_s')),
                ),
              ),
              IconButton(
                tooltip: isFavPoet
                    ? 'إزالة الشاعر من المفضلة'
                    : 'حفظ الشاعر في المفضلة',
                onPressed: () {
                  HapticFeedback.selectionClick();
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
                icon: BaytIconMorph(
                  icon: Icon(
                    isFavPoet
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(isFavPoet),
                    color: isFavPoet ? p.accent : p.ink,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
          ],
        ),
        body: Column(
          children: [
            // Sleek Single-Row Sort & Filter Bar (maximum vertical room for poems!)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                children: [
                  PopupMenuButton<PoemSortBy>(
                    initialValue: _sortBy,
                    onSelected: (v) {
                      HapticFeedback.selectionClick();
                      _sortBy = v;
                      _reloadPoems();
                    },
                    itemBuilder: (_) => PoemSortBy.values
                        .map(
                          (s) => PopupMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: p.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded, size: 14, color: p.accent),
                          const SizedBox(width: 4),
                          Text(
                            _sortBy.label,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: p.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_meters.length > 1) ...[
                    const SizedBox(width: 7),
                    _FilterDropdownPill(
                      icon: Icons.waves_rounded,
                      label: _selectedMeterId == null
                          ? 'البحر'
                          : _meters
                                .firstWhere((m) => m.id == _selectedMeterId)
                                .name,
                      isActive: _selectedMeterId != null,
                      onTap: () => _pickMeter(context),
                    ),
                  ],
                  if (_rhymes.length > 1) ...[
                    const SizedBox(width: 7),
                    _FilterDropdownPill(
                      icon: Icons.music_note_outlined,
                      label: _selectedRhymeId == null
                          ? 'الرويّ'
                          : 'قافية (${_rhymes.firstWhere((r) => r.id == _selectedRhymeId).name})',
                      isActive: _selectedRhymeId != null,
                      onTap: () => _pickRhyme(context),
                    ),
                  ],
                  if (_selectedMeterId != null || _selectedRhymeId != null) ...[
                    const SizedBox(width: 7),
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectedMeterId = null;
                        _selectedRhymeId = null;
                        _reloadPoems();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: p.inkMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'إلغاء',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Sectioned Poems List with Contacts-Style Fast Scrubber
            Expanded(
              child: _poems.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.filter_list_off_rounded,
                      title: 'لا توجد قصائد مطابقة',
                      subtitle:
                          'جرّب تغيير البحر أو حرف الرويّ أو عبارة البحث.',
                    )
                  : SectionFastScroller(
                      sectionLabels: sectionLabels,
                      onSelectSection: (sectionIdx) {
                        if (!_scrollCtrl.hasClients ||
                            sectionIdx >= sectionOffsets.length) {
                          return;
                        }
                        final target = sectionOffsets[sectionIdx].clamp(
                          0.0,
                          _scrollCtrl.position.maxScrollExtent,
                        );
                        _scrollCtrl.jumpTo(target);
                      },
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.fromLTRB(
                          sectionLabels.length >= 3 ? 30 : 16,
                          2,
                          16,
                          28,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          if (entry.isHeader) {
                            return _SectionHeaderBanner(
                              title: entry.sectionTitle!,
                              count: entry.count,
                            );
                          }
                          final poem = entry.poem!;
                          final isFav = userData.favoritePoemIds.contains(
                            poem.id,
                          );
                          return BaytStaggeredItem(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Builder(
                                builder: (cardCtx) => BaytPressable(
                                  child: InkWell(
                                    onTap: () => BaytNav.pushDrop(
                                      context,
                                      PoemReaderScreen(poemId: poem.id),
                                      origin: BaytNav.originFromContext(
                                        cardCtx,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    child: Container(
                                      height: 66,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.surfaceElevated,
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: p.hairline,
                                          width: 0.85,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 31,
                                            height: 31,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: p.surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: p.hairline,
                                                width: 0.85,
                                              ),
                                            ),
                                            child: Text(
                                              poem.rhymeName.length <= 2
                                                  ? poem.rhymeName
                                                  : '۞',
                                              style: TextStyle(
                                                fontFamily: AppFonts.ruqaa,
                                                fontSize: 15,
                                                color: p.accent,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  poem.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        AppFonts.scheherazade,
                                                    fontSize: 17.5,
                                                    color: p.ink,
                                                    height: 1.38,
                                                  ),
                                                ),
                                                Text(
                                                  'بحر ${poem.meterName}  •  الرويّ (${poem.rhymeName})  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontSize: 10.5,
                                                        fontFeatures: const [
                                                          FontFeature.tabularFigures(),
                                                        ],
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isFav)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              child: Icon(
                                                Icons.bookmark_rounded,
                                                size: 16.5,
                                                color: p.accent,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMeter(BuildContext context) async {
    BaytNav.unfocus();
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
      _selectedMeterId = null;
      _reloadPoems();
    } else if (chosen != null) {
      _selectedMeterId = chosen;
      _reloadPoems();
    }
  }

  Future<void> _pickRhyme(BuildContext context) async {
    BaytNav.unfocus();
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
      _selectedRhymeId = null;
      _reloadPoems();
    } else if (chosen != null) {
      _selectedRhymeId = chosen;
      _reloadPoems();
    }
  }
}

class _SectionHeaderBanner extends StatelessWidget {
  const _SectionHeaderBanner({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: p.accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.ruqaa,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 0.7, color: p.hairline)),
          const SizedBox(width: 8),
          Text(
            '${ArabicNormalizer.toArabicNumber(count)} قصيدة',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdownPill extends StatelessWidget {
  const _FilterDropdownPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? p.accentSoft : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? p.accent.withValues(alpha: 0.45) : p.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: isActive ? p.accent : p.inkMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? p.accent : p.ink,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
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
