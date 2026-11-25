import 'dart:async';

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
  static const _pageSize = 50;

  String _query = '';
  bool _searchOpen = false;
  PoetSortBy _sortBy = PoetSortBy.poemsDesc;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Poet> _poets = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _loadingMore = false;
  int _reqGen = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetAndLoad();
    });
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      _loadNextPage();
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) _resetAndLoad();
    });
  }

  Future<void> _resetAndLoad() async {
    final gen = ++_reqGen;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _offset = 0;
      _hasMore = true;
    });
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoetsAsync(
          eraId: widget.era.id,
          filterQuery: _query,
          sortBy: _sortBy,
          limit: _pageSize,
          offset: 0,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poets
        ..clear()
        ..addAll(batch);
      _offset = batch.length;
      _hasMore = batch.length >= _pageSize;
      _initialLoading = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loadingMore) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    final batch = await ref
        .read(poetryRepositoryProvider)
        .getPoetsAsync(
          eraId: widget.era.id,
          filterQuery: _query,
          sortBy: _sortBy,
          limit: _pageSize,
          offset: _offset,
        );
    if (!mounted || gen != _reqGen) return;
    setState(() {
      _poets.addAll(batch);
      _offset += batch.length;
      _hasMore = batch.length >= _pageSize;
      _loadingMore = false;
    });
  }

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
    _resetAndLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                    onChanged: _onQueryChanged,
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'شعراء العصر ${widget.era.name}',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.ruqaa,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '${widget.era.subtitle}  •  ${ArabicNormalizer.toArabicNumber(widget.era.poetCount)} شاعراً',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
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
                        if (_sortBy == s) return;
                        HapticFeedback.selectionClick();
                        setState(() => _sortBy = s);
                        _resetAndLoad();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: BaytMotion.popover,
                switchInCurve: BaytMotion.easeOut,
                child: _initialLoading
                    ? Center(
                        key: const ValueKey('era_poets_loading'),
                        child: CircularProgressIndicator(
                          color: p.accent,
                          strokeWidth: 2.2,
                        ),
                      )
                    : _poets.isEmpty
                    ? const EmptyStateView(
                        key: ValueKey('era_poets_empty'),
                        icon: Icons.person_search_outlined,
                        title: 'لا يوجد شاعرٌ مطابق',
                        subtitle: 'جرّب كتابة جزءٍ من الاسم دون تشكيل.',
                      )
                    : ListView.separated(
                        key: ValueKey(
                          'era_poets_${_sortBy.index}_${_query.trim()}',
                        ),
                        controller: _scrollCtrl,
                        cacheExtent: 600,
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                        itemCount: _poets.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, i) {
                          if (i >= _poets.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: p.accent,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final poet = _poets[i];
                          return PoetCard(
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
}
