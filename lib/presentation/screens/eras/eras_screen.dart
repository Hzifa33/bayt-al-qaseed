import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/poet_card.dart';
import '../../../data/models/poet.dart';
import '../../providers/app_providers.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import 'meter_poems_screen.dart';
import 'poet_detail_screen.dart';
import 'poets_screen.dart';

class ErasScreen extends ConsumerStatefulWidget {
  const ErasScreen({super.key});

  @override
  ConsumerState<ErasScreen> createState() => _ErasScreenState();
}

class _ErasScreenState extends ConsumerState<ErasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _poetFilter = '';
  PoetSortBy _poetSort = PoetSortBy.poemsDesc;
  final TextEditingController _poetSearchCtrl = TextEditingController();
  final FocusNode _poetSearchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) {
        BaytNav.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _poetSearchCtrl.dispose();
    _poetSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eras = ref.watch(erasProvider);
    final meters = ref.watch(metersProvider);
    final favPoetIds = ref.watch(userDataProvider).favoritePoetIds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدواوين والعصور'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: p.accent,
          labelColor: p.accent,
          unselectedLabelColor: p.inkMuted,
          dividerColor: p.hairline,
          tabs: const [
            Tab(
              icon: Icon(Icons.hourglass_bottom_rounded, size: 17),
              text: 'العصور',
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded, size: 17),
              text: 'الشعراء',
            ),
            Tab(icon: Icon(Icons.waves_rounded, size: 17), text: 'البحور'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 1. Literary Eras List
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 102),
            itemCount: eras.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final era = eras[i];
              return InkWell(
                onTap: () =>
                    BaytNav.pushEditorial(context, PoetsScreen(era: era)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ArabicNormalizer.toArabicNumber(era.displayOrder),
                          style: TextStyle(
                            fontFamily: AppFonts.ruqaa,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'العصر ${era.name}',
                                  style: TextStyle(
                                    fontFamily: AppFonts.ruqaa,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  era.periodHint,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: p.accent),
                                ),
                              ],
                            ),
                            Text(
                              era.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.history_edu_rounded,
                                  size: 12.5,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ArabicNormalizer.toArabicNumber(era.poetCount)} شاعراً',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 12.5,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ArabicNormalizer.toArabicNumber(era.poemCount)} قصيدة',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
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
                ),
              );
            },
          ),

          // 2. All Poets Directory (Using Compact Horizontal PoetCard!)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _poetSearchCtrl,
                  focusNode: _poetSearchFocus,
                  onChanged: (v) => setState(() => _poetFilter = v),
                  onTapOutside: (_) => _poetSearchFocus.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الشاعر (مثلاً: المتنبي، جرير، عنترة)…',
                    prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                    suffixIcon: _poetFilter.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _poetSearchCtrl.clear();
                              setState(() => _poetFilter = '');
                              _poetSearchFocus.requestFocus();
                            },
                            icon: Icon(Icons.close_rounded, color: p.inkMuted),
                          )
                        : null,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: PoetSortBy.values.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        selected: _poetSort == s,
                        visualDensity: VisualDensity.compact,
                        label: Text(s.label),
                        onSelected: (_) => setState(() => _poetSort = s),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final poets = ref
                        .read(poetryRepositoryProvider)
                        .getPoets(filterQuery: _poetFilter, sortBy: _poetSort);
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 102),
                      itemCount: poets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final poet = poets[i];
                        return PoetCard(
                          poet: poet,
                          showEra: true,
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
                    );
                  },
                ),
              ),
            ],
          ),

          // 3. Poetic Meters Directory
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 102),
            itemCount: meters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final m = meters[i];
              return InkWell(
                onTap: () =>
                    BaytNav.pushEditorial(context, MeterPoemsScreen(meter: m)),
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
                      Icon(Icons.waves_rounded, size: 19, color: p.accent),
                      const SizedBox(width: 10),
                      Text(
                        'بحر ${m.name}',
                        style: TextStyle(
                          fontFamily: AppFonts.ruqaa,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${ArabicNormalizer.toArabicNumber(m.poemCount)} قصيدة',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: p.inkMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
