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
import '../../../data/models/verse.dart';
import '../../providers/app_providers.dart';
import '../eras/poet_detail_screen.dart';
import '../reader/poem_reader_screen.dart';
import '../studio/poetry_card_studio_screen.dart';

/// Dedicated, sumptuously designed anthology screen for the 120+ most iconic
/// Arabic poems across literary history («عيونُ القصيد الخالدة — أشهر القصائد»).
class MasterpiecesScreen extends ConsumerStatefulWidget {
  const MasterpiecesScreen({super.key, this.initialCategory = 'الكل'});

  final String initialCategory;

  @override
  ConsumerState<MasterpiecesScreen> createState() => _MasterpiecesScreenState();
}

class _MasterpiecesScreenState extends ConsumerState<MasterpiecesScreen> {
  static const _categories = <(String, IconData)>[
    ('الكل', Icons.auto_awesome_rounded),
    ('المعلّقات', Icons.workspace_premium_outlined),
    ('خالدات', Icons.menu_book_outlined),
    ('الرثاء', Icons.water_drop_outlined),
    ('الغزل', Icons.favorite_outline_rounded),
    ('الحكمة', Icons.lightbulb_outline_rounded),
  ];

  late String _selectedCategory;
  String _query = '';
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final Map<String, ScrollController> _tabControllers;
  final ScrollController _searchListCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _tabControllers = {
      for (final (cat, _) in _categories) cat: ScrollController(),
    };
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    for (final ctrl in _tabControllers.values) {
      ctrl.dispose();
    }
    _searchListCtrl.dispose();
    super.dispose();
  }

  void _selectCategory(String cat) {
    HapticFeedback.selectionClick();
    if (_selectedCategory == cat) {
      // Re-tapping the active category smoothly returns to the top
      final ctrl = _query.trim().isNotEmpty
          ? _searchListCtrl
          : _tabControllers[cat];
      if (ctrl != null && ctrl.hasClients && ctrl.offset > 0) {
        ctrl.animateTo(
          0,
          duration: BaytMotion.medium,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() => _selectedCategory = cat);
    if (_query.trim().isNotEmpty && _searchListCtrl.hasClients) {
      _searchListCtrl.jumpTo(0);
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
    _searchCtrl.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = ref.watch(masterpiecesProvider);
    final normQ = ArabicNormalizer.normalize(_query);

    final filtered = all.where((m) {
      if (_selectedCategory != 'الكل' && m.category != _selectedCategory) {
        return false;
      }
      if (normQ.isEmpty) return true;
      final hay = ArabicNormalizer.normalize(
        '${m.tag} ${m.sadr} ${m.ajuz} ${m.poetName} ${m.eraName}',
      );
      return hay.contains(normQ);
    }).toList();

    return PopScope(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchOpen) _closeSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: AnimatedSwitcher(
            duration: BaytMotion.popover,
            child: _searchOpen
                ? TextField(
                    key: const ValueKey('mp_search'),
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'ابحث في أشهر القصائد (مثلاً: مرثية بهاء، معلقة، المتنبي)…',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  )
                : Column(
                    key: const ValueKey('mp_title'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'عيونُ القصيد الخالدة',
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        '${ArabicNormalizer.toArabicNumber(filtered.length)} من أشهر روائع الشعر العربي',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: p.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            IconButton(
              tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث في أشهر القصائد',
              onPressed: _searchOpen ? _closeSearch : _openSearch,
              icon: BaytIconMorph(
                icon: Icon(
                  _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  key: ValueKey(_searchOpen),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            // Subtle Arabic Calligraphy Watermark Backdrop
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: Image.asset(
                    'assets/images/calligraphy_bg.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    color: p.accent.withValues(alpha: isDark ? 0.06 : 0.05),
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Category Filter Ribbon
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final (cat, icon) = _categories[i];
                      final sel = cat == _selectedCategory;
                      final count = cat == 'الكل'
                          ? all.length
                          : all.where((m) => m.category == cat).length;
                      return ChoiceChip(
                        selected: sel,
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          icon,
                          size: 14.5,
                          color: sel ? p.accent : p.inkMuted,
                        ),
                        label: Text(
                          '$cat (${ArabicNormalizer.toArabicNumber(count)})',
                        ),
                        onSelected: (_) => _selectCategory(cat),
                      );
                    },
                  ),
                ),

                // Anthology Cards List — each category preserves its own independent scroll
                // position (new tabs always start from top, returning tabs resume smoothly).
                Expanded(
                  child: normQ.isNotEmpty
                      ? (filtered.isEmpty
                            ? const EmptyStateView(
                                icon: Icons.auto_awesome_outlined,
                                title: 'لا توجد قصيدة مطابقة',
                                subtitle: 'جرّب تغيير التصنيف أو عبارة البحث.',
                              )
                            : ListView.separated(
                                key: ValueKey(
                                  'mp_search_${_selectedCategory}_$normQ',
                                ),
                                controller: _searchListCtrl,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  32,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) =>
                                    _AnthologyMasterpieceCard(
                                      verse: filtered[i],
                                    ),
                              ))
                      : IndexedStack(
                          index: _categories
                              .indexWhere((c) => c.$1 == _selectedCategory)
                              .clamp(0, _categories.length - 1),
                          children: _categories.map((entry) {
                            final cat = entry.$1;
                            final items = cat == 'الكل'
                                ? all
                                : all.where((m) => m.category == cat).toList();
                            if (items.isEmpty) {
                              return const EmptyStateView(
                                icon: Icons.auto_awesome_outlined,
                                title: 'لا توجد قصائد في هذا التصنيف',
                                subtitle: 'جرّب اختيار تصنيفٍ آخر.',
                              );
                            }
                            return ListView.separated(
                              key: PageStorageKey('mp_tab_$cat'),
                              controller: _tabControllers[cat],
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return BaytStaggeredItem(
                                  index: i,
                                  child: _AnthologyMasterpieceCard(verse: item),
                                );
                              },
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnthologyMasterpieceCard extends StatelessWidget {
  const _AnthologyMasterpieceCard({required this.verse});

  final FeaturedVerse verse;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verseStyle = TextStyle(
      fontFamily: AppFonts.scheherazade,
      fontSize: 19.5,
      color: p.ink,
      height: 1.75,
    );

    return BaytPressable(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => BaytNav.pushDrop(
            context,
            PoemReaderScreen(
              poemId: verse.poemId,
              initialVerseIndex: verse.verseIndex,
              highlightMatchedVerseOnce: verse.verseIndex > 0,
            ),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
            decoration: BoxDecoration(
              color: p.surfaceElevated.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: p.ornament.withValues(alpha: 0.42),
                width: 0.95,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Full Famous Poem Title Tag + Verse Count & Card Studio button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: p.accent.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: p.accent,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                verse.tag,
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.accent,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (verse.verseCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${ArabicNormalizer.toArabicNumber(verse.verseCount)} بيتاً',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    const SizedBox(width: 2),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'تصميم بطاقة شعرية',
                      onPressed: () => BaytNav.pushDrop(
                        context,
                        PoetryCardStudioScreen(
                          verses: [verse.toVerse()],
                          poetName: verse.poetName,
                          eraName: verse.eraName,
                        ),
                      ),
                      icon: Icon(
                        Icons.brush_outlined,
                        size: 15.5,
                        color: p.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Highlighted Famous Verse (Sadr & Ajuz)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            verse.sadr,
                            maxLines: 1,
                            style: verseStyle,
                          ),
                        ),
                      ),
                      if (verse.ajuz.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                verse.ajuz,
                                maxLines: 1,
                                style: verseStyle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),

                // Bottom Row: Gender-Aware Poet Avatar + Poet Name + Era
                Row(
                  children: [
                    InkWell(
                      onTap: () => BaytNav.pushEditorial(
                        context,
                        PoetDetailScreen(poetId: verse.poetId),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accentSoft,
                              shape: BoxShape.circle,
                            ),
                            child: PoetAvatarIcon(
                              poetId: verse.poetId,
                              poetName: verse.poetName,
                              size: 14,
                              color: p.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            verse.poetName,
                            style: TextStyle(
                              fontFamily: AppFonts.ruqaa,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: p.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: p.ornament)),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 11.5,
                      color: p.inkMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'العصر ${verse.eraName}',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                    const Spacer(),
                    Text(
                      'قراءة القصيدة',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_left_rounded, size: 15, color: p.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
