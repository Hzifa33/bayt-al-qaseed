import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 13.5,
                      color: p.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.era.subtitle}  •  ${ArabicNormalizer.toArabicNumber(widget.era.poetCount)} شاعراً',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
                          visualDensity: VisualDensity.compact,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: poets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final poet = poets[i];
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
        ],
      ),
    );
  }
}
