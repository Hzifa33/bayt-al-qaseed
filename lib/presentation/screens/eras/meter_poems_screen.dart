import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: Text('بحر ${widget.meter.name}'),
        actions: [
          IconButton(
            tooltip: 'درّةٌ من هذا البحر',
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
        duration: const Duration(milliseconds: 260),
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                itemCount: _poems.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                  return InkWell(
                    onTap: () => BaytNav.pushDrop(
                      context,
                      PoemReaderScreen(poemId: poem.id),
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
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${poem.poetName}  •  العصر ${poem.eraName}  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
