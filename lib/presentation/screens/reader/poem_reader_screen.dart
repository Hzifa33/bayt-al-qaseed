import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/utils/share_formatter.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/verse_renderer.dart';
import '../../../data/models/poem.dart';
import '../../../data/models/reader_settings.dart';
import '../../../data/models/verse.dart';
import '../../providers/database_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_providers.dart';
import '../eras/poet_detail_screen.dart';
import '../studio/poetry_card_studio_screen.dart';
import 'reader_settings_sheet.dart';

class PoemReaderScreen extends ConsumerStatefulWidget {
  const PoemReaderScreen({
    super.key,
    required this.poemId,
    this.initialVerseIndex,
    this.highlightMatchedVerseOnce = false,
  });

  final int poemId;
  final int? initialVerseIndex;
  final bool highlightMatchedVerseOnce;

  @override
  ConsumerState<PoemReaderScreen> createState() => _PoemReaderScreenState();
}

class _PoemReaderScreenState extends ConsumerState<PoemReaderScreen> {
  PoemDetail? _poem;
  int? _prevPoemId;
  int? _nextPoemId;
  final Set<int> _selectedIndices = {};
  final ScrollController _scrollCtrl = ScrollController();
  bool _chromeVisible = true;
  bool _typographyPanelOpen = false;
  double _readProgress = 0.0;
  int? _transientHighlightIndex;

  @override
  void initState() {
    super.initState();
    _loadPoem(
      widget.poemId,
      initialIndex: widget.initialVerseIndex,
      pulseTargetVerse: widget.highlightMatchedVerseOnce,
    );
    _scrollCtrl.addListener(_onScroll);
  }

  void _loadPoem(
    int poemId, {
    int? initialIndex,
    bool pulseTargetVerse = false,
  }) {
    final repo = ref.read(poetryRepositoryProvider);
    final poem = repo.getPoemById(poemId);
    _poem = poem;
    _transientHighlightIndex = (pulseTargetVerse && initialIndex != null)
        ? initialIndex
        : null;

    if (poem != null) {
      final adj = repo.getAdjacentPoemIds(poem.poetId, poem.id);
      _prevPoemId = adj.$1;
      _nextPoemId = adj.$2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(userDataProvider.notifier)
            .recordReading(poem, lastVerseIndex: initialIndex ?? 0);
        if (initialIndex != null &&
            initialIndex > 1 &&
            _scrollCtrl.hasClients) {
          final isStaggered =
              ref.read(readerSettingsProvider).verseLayout ==
              VerseLayoutStyle.staggered;
          final rowHeight = isStaggered ? 104.0 : 58.0;
          final targetOffset = (150.0 + initialIndex * rowHeight - 130.0).clamp(
            0.0,
            _scrollCtrl.position.maxScrollExtent,
          );
          _scrollCtrl.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
        // Gently highlight ONLY the target verse for ~1.3s, then clear completely
        // so the reader reads peacefully without any lingering highlights.
        if (_transientHighlightIndex != null) {
          Future.delayed(const Duration(milliseconds: 1300), () {
            if (mounted) {
              setState(() => _transientHighlightIndex = null);
            }
          });
        }
      });
    }
  }

  void _switchToAdjacentPoem(int targetPoemId) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndices.clear();
      _typographyPanelOpen = false;
      _readProgress = 0;
      _loadPoem(targetPoemId);
    });
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients) {
      final max = _scrollCtrl.position.maxScrollExtent;
      final nextProgress = max > 0
          ? (_scrollCtrl.offset / max).clamp(0.0, 1.0)
          : 0.0;
      if ((nextProgress - _readProgress).abs() > 0.01) {
        setState(() => _readProgress = nextProgress);
      }
    }
    if (_selectedIndices.isNotEmpty || _typographyPanelOpen) return;
    final dir = _scrollCtrl.position.userScrollDirection;
    if (dir == ScrollDirection.reverse &&
        _chromeVisible &&
        _scrollCtrl.offset > 80) {
      setState(() => _chromeVisible = false);
    } else if (dir == ScrollDirection.forward && !_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
  }

  List<Verse> get _selectedVerses {
    final poem = _poem;
    if (poem == null) return const [];
    final sorted = _selectedIndices.toList()..sort();
    return [
      for (final idx in sorted)
        if (idx >= 0 && idx < poem.verses.length) poem.verses[idx],
    ];
  }

  void _toggleVerseSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _typographyPanelOpen = false;
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
        _chromeVisible = true;
      }
    });
  }

  void _copyVerses(List<Verse> verses) {
    final poem = _poem!;
    final settings = ref.read(readerSettingsProvider);
    final text = ShareFormatter.formatVerses(
      verses: verses,
      poetName: poem.poetName,
      meterName: poem.meterName,
      showDiacritics: settings.showDiacritics,
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verses.length == 1
              ? 'نُسخ البيت إلى الحافظة'
              : 'نُسخت ${ArabicNormalizer.toArabicNumber(verses.length)} أبيات إلى الحافظة',
        ),
      ),
    );
  }

  void _shareVersesText(List<Verse> verses) {
    final poem = _poem!;
    final settings = ref.read(readerSettingsProvider);
    final text = ShareFormatter.formatVerses(
      verses: verses,
      poetName: poem.poetName,
      meterName: poem.meterName,
      showDiacritics: settings.showDiacritics,
    );
    Share.share(text);
  }

  void _openCardStudio(List<Verse> verses) {
    final poem = _poem!;
    BaytNav.pushDrop(
      context,
      PoetryCardStudioScreen(
        verses: verses,
        poetName: poem.poetName,
        eraName: poem.eraName,
        meterName: poem.meterName,
      ),
    );
  }

  void _saveSelectedVerses() {
    final poem = _poem!;
    final verses = _selectedVerses;
    if (verses.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(userDataProvider.notifier).saveFavoriteVerses(poem, verses);
    setState(() => _selectedIndices.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verses.length == 1
              ? 'حُفظ البيت في مكتبة الأبيات المحفوظة'
              : 'حُفظت ${ArabicNormalizer.toArabicNumber(verses.length)} أبيات في مكتبتك',
        ),
      ),
    );
  }

  void _openPoemInfoSheet() {
    final poem = _poem!;
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded, size: 22, color: p.accent),
                  const SizedBox(width: 8),
                  Text(
                    'بطاقة القصيدة',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.history_edu_rounded,
                label: 'الشاعر',
                value: poem.poetName,
              ),
              _InfoRow(
                icon: Icons.hourglass_bottom_rounded,
                label: 'العصر الأدبي',
                value: 'العصر ${poem.eraName}',
              ),
              _InfoRow(
                icon: Icons.waves_rounded,
                label: 'البحر العروضي',
                value: poem.meterName,
              ),
              if (poem.meterNote.isNotEmpty)
                _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'ملاحظة عروضية',
                  value: poem.meterNote,
                ),
              _InfoRow(
                icon: Icons.music_note_outlined,
                label: 'حرف الرويّ',
                value: poem.rhymeName,
              ),
              _InfoRow(
                icon: Icons.format_list_numbered_rtl_rounded,
                label: 'عدد الأبيات',
                value:
                    '${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
              ),
              _InfoRow(
                icon: Icons.spellcheck_rounded,
                label: 'التشكيل',
                value: poem.hasDiacritics
                    ? 'مضبوطة بالتشكيل العربي'
                    : 'غير مشكّلة',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  BaytNav.pushEditorial(
                    context,
                    PoetDetailScreen(poetId: poem.poetId),
                  );
                },
                icon: const Icon(Icons.person_outline_rounded),
                label: Text('الانتقال إلى ديوان ${poem.poetName}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCollectionsSheet() {
    final poem = _poem!;
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final userData = ref.watch(userDataProvider);
          final memberIds = ref
              .read(userDataProvider.notifier)
              .getCollectionIdsForPoem(poem.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.collections_bookmark_outlined,
                        size: 20,
                        color: p.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إضافة إلى مجموعة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showCreateCollectionDialog(context),
                        icon: Icon(
                          Icons.add_rounded,
                          color: p.accent,
                          size: 18,
                        ),
                        label: Text('جديدة', style: TextStyle(color: p.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (userData.collections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'لم تُنشئ مجموعةً بعد؛ أنشئ مجموعة لتصنيف مختاراتك الشعرية.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ...userData.collections.map((c) {
                      final inCol = memberIds.contains(c.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: inCol,
                        activeColor: p.accent,
                        title: Text(c.name),
                        subtitle: Text(
                          '${ArabicNormalizer.toArabicNumber(c.poemCount)} قصيدة',
                        ),
                        onChanged: (_) => ref
                            .read(userDataProvider.notifier)
                            .togglePoemInCollection(c.id, poem.id),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateCollectionDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مجموعة جديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اسم المجموعة (مثلاً: عيون الحكمة)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        final colId = ref
            .read(userDataProvider.notifier)
            .createCollection(name);
        ref
            .read(userDataProvider.notifier)
            .togglePoemInCollection(colId, _poem!.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('توجد مجموعةٌ بهذا الاسم مسبقاً')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poem = _poem;
    if (poem == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateView(
          icon: Icons.error_outline,
          title: 'تعذّر تحميل القصيدة',
          subtitle: 'لم نتمكن من العثور على هذا النص الشعري.',
        ),
      );
    }

    final p = context.palette;
    final settings = ref.watch(readerSettingsProvider);
    final userData = ref.watch(userDataProvider);
    final isFavPoem = userData.favoritePoemIds.contains(poem.id);
    final inSelection = _selectedIndices.isNotEmpty;

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final harmoniousSize = computePoemHarmoniousFontSize(
      verses: poem.verses,
      font: settings.poetryFont,
      requestedFontSize: settings.fontSize,
      layoutStyle: settings.verseLayout,
      showDiacritics: settings.showDiacritics,
      showVerseNumbers: settings.showVerseNumbers,
      viewportWidth: viewportWidth,
      textScaler: textScaler,
    );

    final interceptBack = inSelection || _typographyPanelOpen;

    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_typographyPanelOpen) {
          setState(() => _typographyPanelOpen = false);
        } else if (inSelection) {
          setState(() => _selectedIndices.clear());
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Main Immersive Reading Surface
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_typographyPanelOpen) {
                  setState(() => _typographyPanelOpen = false);
                } else if (!inSelection) {
                  setState(() => _chromeVisible = !_chromeVisible);
                }
              },
              child: SafeArea(
                bottom: false,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    70,
                    12,
                    _typographyPanelOpen
                        ? 230
                        : inSelection
                        ? 124
                        : 102,
                  ),
                  itemCount: poem.verses.length + 2,
                  itemBuilder: (context, idx) {
                    // Editorial Poem Header with Expressive Icons
                    if (idx == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => BaytNav.pushEditorial(
                                context,
                                PoetDetailScreen(poetId: poem.poetId),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history_edu_rounded,
                                      size: 20,
                                      color: p.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        poem.poetName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: AppFonts.ruqaa,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: p.accent,
                                          height: 1.38,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                _HeaderPill(
                                  icon: Icons.hourglass_bottom_rounded,
                                  label: 'العصر ${poem.eraName}',
                                ),
                                _HeaderPill(
                                  icon: Icons.waves_rounded,
                                  label: 'بحر ${poem.meterName}',
                                ),
                                _HeaderPill(
                                  icon: Icons.music_note_outlined,
                                  label: 'الرويّ (${poem.rhymeName})',
                                ),
                                _HeaderPill(
                                  icon: Icons.format_list_numbered_rtl_rounded,
                                  label:
                                      '${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                ),
                              ],
                            ),
                            const EditorialDivider(
                              verticalPadding: 16,
                              horizontalPadding: 32,
                            ),
                          ],
                        ),
                      );
                    }

                    // Footer: Correctly Oriented RTL Adjacent Poem Navigation
                    if (idx == poem.verses.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 20),
                        child: Column(
                          children: [
                            const EditorialDivider(
                              verticalPadding: 12,
                              horizontalPadding: 54,
                            ),
                            if (_prevPoemId != null || _nextPoemId != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    // In RTL: «القصيدة السابقة» sits on the RIGHT and points RIGHT (east ->)
                                    if (_prevPoemId != null)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _switchToAdjacentPoem(
                                                _prevPoemId!,
                                              ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 11,
                                              horizontal: 10,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.east_rounded,
                                                size: 17,
                                              ),
                                              SizedBox(width: 6),
                                              Text('القصيدة السابقة'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_prevPoemId != null &&
                                        _nextPoemId != null)
                                      const SizedBox(width: 10),
                                    // In RTL: «القصيدة التالية» sits on the LEFT and points LEFT (west <-)
                                    if (_nextPoemId != null)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _switchToAdjacentPoem(
                                                _nextPoemId!,
                                              ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 11,
                                              horizontal: 10,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('القصيدة التالية'),
                                              SizedBox(width: 6),
                                              Icon(
                                                Icons.west_rounded,
                                                size: 17,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'اضغط مطوّلاً على أيّ بيتٍ لتحديده أو حفظه أو تصميمه كبطاقة شعرية',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      );
                    }

                    final verse = poem.verses[idx - 1];
                    final selected = _selectedIndices.contains(verse.index);
                    final isTransientPulse =
                        _transientHighlightIndex == verse.index;

                    return VerseRowWidget(
                      verse: verse,
                      font: settings.poetryFont,
                      fontSize: harmoniousSize,
                      layoutStyle: settings.verseLayout,
                      showDiacritics: settings.showDiacritics,
                      showVerseNumber: settings.showVerseNumbers,
                      isSelected: selected,
                      isHighlightedVerse: isTransientPulse,
                      // Never highlight individual words inside the poem
                      searchHighlightQuery: null,
                      onTap: () {
                        if (_typographyPanelOpen) {
                          setState(() => _typographyPanelOpen = false);
                        } else if (inSelection) {
                          _toggleVerseSelection(verse.index);
                        } else {
                          setState(() => _chromeVisible = !_chromeVisible);
                        }
                      },
                      onLongPress: () => _toggleVerseSelection(verse.index),
                    );
                  },
                ),
              ),
            ),

            // Whisper-Thin Top Reading Progress Hairline
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: LinearProgressIndicator(
                  value: _readProgress,
                  minHeight: 2.2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    p.accent.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),

            // Immersive Auto-Hiding Top Bar (Correct RTL Back Arrow: east_rounded -> points right!)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: (_chromeVisible || inSelection || _typographyPanelOpen)
                  ? 0
                  : -110,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: p.canvas.withValues(alpha: 0.96),
                  border: Border(
                    bottom: BorderSide(color: p.hairline, width: 0.7),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 56,
                    child: inSelection
                        ? Row(
                            children: [
                              IconButton(
                                tooltip: 'إلغاء التحديد',
                                onPressed: () =>
                                    setState(() => _selectedIndices.clear()),
                                icon: const Icon(Icons.close_rounded),
                              ),
                              Text(
                                'محدّد ${ArabicNormalizer.toArabicNumber(_selectedIndices.length)} بيت',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedIndices.length ==
                                        poem.verses.length) {
                                      _selectedIndices.clear();
                                    } else {
                                      _selectedIndices.addAll(
                                        List.generate(
                                          poem.verses.length,
                                          (i) => i,
                                        ),
                                      );
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedIndices.length == poem.verses.length
                                      ? 'إلغاء الكل'
                                      : 'تحديد الكل',
                                  style: TextStyle(color: p.accent),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Correct Arabic RTL Back Arrow pointing RIGHT (->)
                              IconButton(
                                tooltip: 'رجوع',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.east_rounded),
                              ),
                              Icon(
                                Icons.history_edu_rounded,
                                size: 17,
                                color: p.accent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  poem.poetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: 'بطاقة القصيدة',
                                onPressed: _openPoemInfoSheet,
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 21,
                                ),
                              ),
                              IconButton(
                                tooltip: 'إضافة إلى مجموعة',
                                onPressed: _openCollectionsSheet,
                                icon: const Icon(
                                  Icons.playlist_add_rounded,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                tooltip: isFavPoem
                                    ? 'إزالة من المفضلة'
                                    : 'حفظ القصيدة',
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  final added = ref
                                      .read(userDataProvider.notifier)
                                      .toggleFavoritePoem(poem.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        added
                                            ? 'حُفظت القصيدة في المفضلة'
                                            : 'أُزيلت القصيدة من المفضلة',
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  isFavPoem
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  color: isFavPoem ? p.accent : p.ink,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Live Non-Obstructive Typography Dock
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutQuart,
              bottom: _typographyPanelOpen ? 0 : -280,
              left: 0,
              right: 0,
              child: LiveTypographyPanel(
                poemHasDiacritics: poem.hasDiacritics,
                onClose: () => setState(() => _typographyPanelOpen = false),
              ),
            ),

            // Bottom Floating Reader Controls OR Multi-Verse Selection Dock
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              bottom: (!_typographyPanelOpen && (_chromeVisible || inSelection))
                  ? 14
                  : -120,
              left: 16,
              right: 16,
              child: SafeArea(
                top: false,
                child: inSelection
                    ? _SelectionActionBar(
                        onCopy: () => _copyVerses(_selectedVerses),
                        onSave: _saveSelectedVerses,
                        onShareText: () => _shareVersesText(_selectedVerses),
                        onDesignCard: () => _openCardStudio(_selectedVerses),
                      )
                    : _ReaderBottomBar(
                        poemHasDiacritics: poem.hasDiacritics,
                        showDiacritics: settings.showDiacritics,
                        onOpenTypography: () {
                          HapticFeedback.selectionClick();
                          setState(() => _typographyPanelOpen = true);
                        },
                        onToggleDiacritics: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(readerSettingsProvider.notifier)
                              .toggleDiacritics();
                        },
                        onDesignCard: () =>
                            _openCardStudio(poem.verses.take(3).toList()),
                        onSharePoem: () => _shareVersesText(poem.verses),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: p.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: p.accent),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: p.inkMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.poemHasDiacritics,
    required this.showDiacritics,
    required this.onOpenTypography,
    required this.onToggleDiacritics,
    required this.onDesignCard,
    required this.onSharePoem,
  });

  final bool poemHasDiacritics;
  final bool showDiacritics;
  final VoidCallback onOpenTypography;
  final VoidCallback onToggleDiacritics;
  final VoidCallback onDesignCard;
  final VoidCallback onSharePoem;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceElevated.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.ornament.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BarAction(
            icon: Icons.text_fields_rounded,
            label: 'هيئة القراءة',
            onTap: onOpenTypography,
          ),
          if (poemHasDiacritics)
            _BarAction(
              icon: showDiacritics
                  ? Icons.spellcheck_rounded
                  : Icons.format_clear_rounded,
              label: showDiacritics ? 'التشكيل' : 'بلا تشكيل',
              isHighlighted: showDiacritics,
              onTap: onToggleDiacritics,
            ),
          _BarAction(
            icon: Icons.brush_outlined,
            label: 'بطاقة شعرية',
            onTap: onDesignCard,
          ),
          _BarAction(
            icon: Icons.share_outlined,
            label: 'مشاركة',
            onTap: onSharePoem,
          ),
        ],
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.onCopy,
    required this.onSave,
    required this.onShareText,
    required this.onDesignCard,
  });

  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onShareText;
  final VoidCallback onDesignCard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.accent.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BarAction(icon: Icons.copy_rounded, label: 'نسخ', onTap: onCopy),
          _BarAction(
            icon: Icons.favorite_outline_rounded,
            label: 'حفظ البيت',
            onTap: onSave,
          ),
          _BarAction(
            icon: Icons.brush_outlined,
            label: 'بطاقة فنية',
            isHighlighted: true,
            onTap: onDesignCard,
          ),
          _BarAction(
            icon: Icons.share_outlined,
            label: 'مشاركة',
            onTap: onShareText,
          ),
        ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = isHighlighted ? p.accent : p.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10.5,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
