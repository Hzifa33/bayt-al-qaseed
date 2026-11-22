import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
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
  PoetSortBy _sortBy = PoetSortBy.poemsDesc;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

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

    return Scaffold(
      appBar: AppBar(title: Text('شعراء العصر ${widget.era.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.era.subtitle}  •  ${ArabicNormalizer.toArabicNumber(widget.era.poetCount)} شاعراً',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: (v) => setState(() => _query = v),
                  onTapOutside: (_) => _focus.unfocus(),
                  decoration: InputDecoration(
                    hintText: 'تصفية شعراء العصر ${widget.era.name}…',
                    prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                              _focus.requestFocus();
                            },
                            icon: Icon(Icons.close_rounded, color: p.inkMuted),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PoetSortBy.values.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          selected: _sortBy == s,
                          label: Text(s.label),
                          onSelected: (_) => setState(() => _sortBy = s),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                    itemCount: poets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final poet = poets[i];
                      final isFav = favPoetIds.contains(poet.id);
                      return InkWell(
                        onTap: () => BaytNav.pushEditorial(
                          context,
                          PoetDetailScreen(poetId: poet.id),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.hairline),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      poet.name,
                                      style: TextStyle(
                                        fontFamily: AppFonts.scheherazade,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: p.ink,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (poet.formattedDates.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        poet.formattedDates,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '${ArabicNormalizer.toArabicNumber(poet.poemCount)} قصيدة  •  ${ArabicNormalizer.toArabicNumber(poet.verseCount)} بيتاً',
                                      style: TextStyle(
                                        fontFamily: AppFonts.ui,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: p.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: isFav
                                    ? 'إزالة من المفضلة'
                                    : 'إضافة للمفضلة',
                                onPressed: () => ref
                                    .read(userDataProvider.notifier)
                                    .toggleFavoritePoet(poet.id),
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav ? p.accent : p.inkMuted,
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
}
