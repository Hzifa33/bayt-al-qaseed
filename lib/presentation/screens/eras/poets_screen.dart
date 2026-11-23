import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/poet_card.dart';
import '../../../data/models/era.dart';
import '../../../data/models/poet.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import 'poet_detail_screen.dart';

class PoetsScreen extends ConsumerStatefulWidget {
  const PoetsScreen({super.key, required this.era});

  final Era era;

  @override
  ConsumerState<PoetsScreen> createState() => _PoetsScreenState();
}

class _PoetsScreenState extends ConsumerState<PoetsScreen> {
  String _query = '';
  bool _searchOpen = false;
  PoetSortBy _sortBy = PoetSortBy.poemsDesc;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  void _openSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    _focus.unfocus();
    _ctrl.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final poets = ref
        .read(poetryRepositoryProvider)
        .getPoets(eraId: widget.era.id, filterQuery: _query, sortBy: _sortBy);
    final favPoetIds = ref.watch(userDataProvider).favoritePoetIds;

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
            switchInCurve: BaytMotion.easeOut,
            switchOutCurve: BaytMotion.exit,
            child: _searchOpen
                ? TextField(
                    key: const ValueKey('era_poets_search'),
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: (v) => setState(() => _query = v),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'ابحث في شعراء العصر ${widget.era.name}…',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  )
                : Column(
                    key: const ValueKey('era_poets_title'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'شعراء العصر ${widget.era.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        '${widget.era.subtitle}  •  ${ArabicNormalizer.toArabicNumber(widget.era.poetCount)} شاعراً',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            IconButton(
              tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث في شعراء العصر',
              onPressed: _searchOpen ? _closeSearch : _openSearch,
              icon: BaytIconMorph(
                icon: Icon(
                  _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  key: ValueKey(_searchOpen),
                ),
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                children: PoetSortBy.values.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      selected: _sortBy == s,
                      visualDensity: VisualDensity.compact,
                      label: Text(s.label),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _sortBy = s);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: poets.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.person_search_outlined,
                      title: 'لا يوجد شاعرٌ مطابق',
                      subtitle: 'جرّب كتابة جزءٍ من الاسم دون تشكيل.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                      itemCount: poets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (context, i) {
                        final poet = poets[i];
                        return BaytStaggeredItem(
                          index: i,
                          child: PoetCard(
                            poet: poet,
                            showEra: false,
                            isFavorite: favPoetIds.contains(poet.id),
                            onTap: () => BaytNav.pushEditorial(
                              context,
                              PoetDetailScreen(poetId: poet.id),
                            ),
                            onToggleFavorite: () => ref
                                .read(userDataProvider.notifier)
                                .toggleFavoritePoet(poet.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
