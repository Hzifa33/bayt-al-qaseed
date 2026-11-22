import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
            Tab(text: 'العصور'),
            Tab(text: 'الشعراء'),
            Tab(text: 'البحور'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 1. Eras List
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            itemCount: eras.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final era = eras[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PoetsScreen(era: era)),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          ArabicNormalizer.toArabicNumber(era.displayOrder),
                          style: TextStyle(
                            fontFamily: AppFonts.ruqaa,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                                    fontSize: 21,
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
                            const SizedBox(height: 2),
                            Text(
                              era.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${ArabicNormalizer.toArabicNumber(era.poetCount)} شاعراً  •  ${ArabicNormalizer.toArabicNumber(era.poemCount)} قصيدة',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: p.inkMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. All Poets Directory
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: TextField(
                  onChanged: (v) => setState(() => _poetFilter = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الشاعر (مثلاً: المتنبي، جرير، عنترة)…',
                    prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                  ),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final poets = ref
                        .read(poetryRepositoryProvider)
                        .getPoets(filterQuery: _poetFilter);
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                      itemCount: poets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final poet = poets[i];
                        final isFav = favPoetIds.contains(poet.id);
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PoetDetailScreen(poetId: poet.id),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        poet.name,
                                        style: TextStyle(
                                          fontFamily: AppFonts.scheherazade,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700,
                                          color: p.ink,
                                          height: 1.45,
                                        ),
                                      ),
                                      Text(
                                        'العصر ${poet.eraName}  •  ${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(userDataProvider.notifier)
                                      .toggleFavoritePoet(poet.id),
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav ? p.accent : p.inkMuted,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            itemCount: meters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = meters[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MeterPoemsScreen(meter: m)),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Row(
                    children: [
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
                            fontSize: 12,
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
