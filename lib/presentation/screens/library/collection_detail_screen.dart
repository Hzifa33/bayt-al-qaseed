import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/user_collection.dart';
import '../../providers/database_providers.dart';
import '../../providers/user_data_providers.dart';
import '../reader/poem_reader_screen.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collection});

  final UserCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userDataProvider);
    final p = context.palette;
    final ids = ref
        .read(userRepositoryProvider)
        .getCollectionPoemIds(collection.id);
    final poems = ref.read(poetryRepositoryProvider).getPoemsByIds(ids);

    return Scaffold(
      appBar: AppBar(title: Text(collection.name)),
      body: poems.isEmpty
          ? const EmptyStateView(
              icon: Icons.playlist_add_rounded,
              title: 'هذه المجموعة فارغةٌ حالياً',
              subtitle: 'افتح أيّ قصيدةٍ واضغط على أيقونة الإضافة للمجموعات لحفظها هنا.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              itemCount: poems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final poem = poems[i];
                return InkWell(
                  onTap: () => BaytNav.pushDrop(
                    context,
                    PoemReaderScreen(poemId: poem.id),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Row(
                      children: [
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
                                ),
                              ),
                              Text(
                                '${poem.poetName}  •  بحر ${poem.meterName}  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'إزالة من المجموعة',
                          onPressed: () => ref
                              .read(userDataProvider.notifier)
                              .togglePoemInCollection(collection.id, poem.id),
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            color: p.inkMuted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
