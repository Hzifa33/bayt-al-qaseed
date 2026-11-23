import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/poem.dart';
import '../../providers/database_providers.dart';
import '../reader/poem_reader_screen.dart';

class MeterPoemsScreen extends ConsumerStatefulWidget {
  const MeterPoemsScreen({super.key, required this.meter});

  final Meter meter;

  @override
  ConsumerState<MeterPoemsScreen> createState() => _MeterPoemsScreenState();
}

class _MeterPoemsScreenState extends ConsumerState<MeterPoemsScreen> {
  final List<PoemSummary> _poems = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer initial load cleanly past first frame so the page slide animation runs at 60/120fps!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
  }

  void _loadMore() {
    if (!_hasMore) return;
    final batch = ref
        .read(poetryRepositoryProvider)
        .getPoemsByMeter(widget.meter.id, limit: 60, offset: _offset);
    setState(() {
      _poems.addAll(batch);
      _offset += batch.length;
      _initialLoading = false;
      if (batch.length < 60) _hasMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'بحر ${widget.meter.name}',
              style: TextStyle(
                fontFamily: AppFonts.ruqaa,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: p.ink,
                height: 1.25,
              ),
            ),
            Text(
              '${ArabicNormalizer.toArabicNumber(widget.meter.poemCount)} قصيدة',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'قصيدة عشوائية من هذا البحر',
            onPressed: () {
              final rnd = ref
                  .read(poetryRepositoryProvider)
                  .getRandomPoem(meterId: widget.meter.id);
              if (rnd != null) {
                BaytNav.pushDrop(context, PoemReaderScreen(poemId: rnd.id));
              }
            },
            icon: Icon(Icons.auto_awesome_outlined, color: p.accent),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: BaytMotion.popover,
        switchInCurve: BaytMotion.easeOut,
        child: _initialLoading
            ? Center(
                key: const ValueKey('loading'),
                child: CircularProgressIndicator(
                  color: p.accent,
                  strokeWidth: 2.2,
                ),
              )
            : ListView.separated(
                key: const ValueKey('list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                itemCount: _poems.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  if (i >= _poems.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: OutlinedButton(
                          onPressed: _loadMore,
                          child: const Text('عرض مزيدٍ من القصائد'),
                        ),
                      ),
                    );
                  }
                  final poem = _poems[i];
                  return BaytStaggeredItem(
                    index: i,
                    child: Builder(
                      builder: (cardCtx) => BaytPressable(
                        child: InkWell(
                          onTap: () => BaytNav.pushDrop(
                            context,
                            PoemReaderScreen(poemId: poem.id),
                            origin: BaytNav.originFromContext(cardCtx),
                          ),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: p.hairline,
                                width: 0.85,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  poem.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.scheherazade,
                                    fontSize: 17.5,
                                    color: p.ink,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 11.5,
                                      color: p.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${poem.poetName}  •  ${poem.eraName}  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
