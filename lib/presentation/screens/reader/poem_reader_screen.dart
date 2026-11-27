import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/bayt_motion.dart';
import '../../../core/animations/bayt_transitions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/utils/share_formatter.dart';
import '../../../core/widgets/bayt_ornaments.dart';
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
    this.isRawVerseIndex = false,
    this.highlightMatchedVerseOnce = false,
  });

  final int poemId;
  final int? initialVerseIndex;
  final bool isRawVerseIndex;
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
  final GlobalKey _targetVerseKey = GlobalKey();
  final ValueNotifier<double> _readProgress = ValueNotifier<double>(0.0);
  final TextEditingController _inPoemSearchCtrl = TextEditingController();
  final FocusNode _inPoemSearchFocus = FocusNode();
  bool _chromeVisible = true;
  bool _typographyPanelOpen = false;
  bool _inPoemSearchOpen = false;
  String _inPoemQuery = '';
  List<int> _inPoemMatchIndices = const [];
  int _inPoemMatchCursor = 0;
  int? _targetScrollIndex;
  int? _transientHighlightIndex;
  int _lastBuiltVerse = 0;
  Timer? _highlightTimer;
  String? _cachedHarmoniousKey;
  double? _cachedHarmoniousSize;

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
    _highlightTimer?.cancel();
    final repo = ref.read(poetryRepositoryProvider);
    final poem = repo.getPoemById(poemId);
    _poem = poem;
    final resolvedInitial =
        (poem != null && initialIndex != null && poem.verses.isNotEmpty)
        ? (widget.isRawVerseIndex
              ? Verse.resolveGroupedIndex(poem.verses, initialIndex)
              : initialIndex.clamp(0, poem.verses.length - 1))
        : initialIndex;
    _targetScrollIndex = resolvedInitial;
    _transientHighlightIndex = null;
    _lastBuiltVerse = 0;

    if (poem != null) {
      final adj = repo.getAdjacentPoemIds(poem.poetId, poem.id);
      _prevPoemId = adj.$1;
      _nextPoemId = adj.$2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(userDataProvider.notifier)
            .recordReading(poem, lastVerseIndex: resolvedInitial ?? 0);
        if (resolvedInitial != null && resolvedInitial >= 0) {
          _scrollToExactVerseCenter(
            targetIndex: resolvedInitial,
            pulseAfterCenter: pulseTargetVerse,
          );
        }
      });
    }
  }

  void _startTransientPulse(int targetIndex) {
    _highlightTimer?.cancel();
    if (!mounted) return;
    setState(() => _transientHighlightIndex = targetIndex);
    _highlightTimer = Timer(const Duration(milliseconds: 1450), () {
      if (mounted) {
        setState(() => _transientHighlightIndex = null);
      }
    });
  }

  /// Deterministically scrolls [targetIndex] into the exact vertical middle of
  /// the reading viewport, even in 300+ verse poems with variable row heights.
  void _scrollToExactVerseCenter({
    required int targetIndex,
    required bool pulseAfterCenter,
    int attempt = 0,
  }) {
    if (!mounted || !_scrollCtrl.hasClients || _poem == null) return;

    final targetCtx = _targetVerseKey.currentContext;
    if (targetCtx != null) {
      Scrollable.ensureVisible(
        targetCtx,
        alignment: 0.5,
        duration: Duration(milliseconds: attempt == 0 ? 320 : 220),
        curve: Curves.easeOutCubic,
      ).then((_) {
        if (mounted && pulseAfterCenter) {
          _startTransientPulse(targetIndex);
        }
      });
      return;
    }

    if (attempt >= 12) {
      if (pulseAfterCenter) _startTransientPulse(targetIndex);
      return;
    }

    final settings = ref.read(readerSettingsProvider);
    final isStaggered = settings.verseLayout == VerseLayoutStyle.staggered;
    final scaledLine =
        settings.fontSize *
        settings.poetryFont.scaleMultiplier *
        settings.poetryFont.baseHeight;
    final estRowHeight = isStaggered
        ? (scaledLine * 2.0 + 28.0)
        : (scaledLine + 20.0);
    final viewport = _scrollCtrl.position.viewportDimension;
    final maxExtent = _scrollCtrl.position.maxScrollExtent;

    double nextOffset;
    if (attempt == 0) {
      nextOffset = (110.0 + targetIndex * estRowHeight - viewport * 0.45).clamp(
        0.0,
        maxExtent,
      );
    } else {
      final deltaVerses = targetIndex - _lastBuiltVerse;
      final step = deltaVerses == 0 ? 0.0 : deltaVerses * estRowHeight * 0.85;
      nextOffset = (_scrollCtrl.offset + step).clamp(0.0, maxExtent);
    }

    _scrollCtrl.jumpTo(nextOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToExactVerseCenter(
        targetIndex: targetIndex,
        pulseAfterCenter: pulseAfterCenter,
        attempt: attempt + 1,
      );
    });
  }

  void _switchToAdjacentPoem(int targetPoemId) {
    HapticFeedback.lightImpact();
    _inPoemSearchFocus.unfocus();
    _inPoemSearchCtrl.clear();
    setState(() {
      _selectedIndices.clear();
      _typographyPanelOpen = false;
      _inPoemSearchOpen = false;
      _inPoemQuery = '';
      _inPoemMatchIndices = const [];
      _inPoemMatchCursor = 0;
      _cachedHarmoniousKey = null;
      _readProgress.value = 0.0;
      _loadPoem(targetPoemId);
    });
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  void _openInPoemSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _inPoemSearchOpen = true;
      _typographyPanelOpen = false;
      _chromeVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inPoemSearchFocus.requestFocus();
    });
  }

  void _closeInPoemSearch() {
    _inPoemSearchFocus.unfocus();
    _inPoemSearchCtrl.clear();
    setState(() {
      _inPoemSearchOpen = false;
      _inPoemQuery = '';
      _inPoemMatchIndices = const [];
      _inPoemMatchCursor = 0;
    });
  }

  void _onInPoemQueryChanged(String raw) {
    final poem = _poem;
    final trimmed = raw.trim();
    if (poem == null || trimmed.isEmpty) {
      setState(() {
        _inPoemQuery = '';
        _inPoemMatchIndices = const [];
        _inPoemMatchCursor = 0;
      });
      return;
    }
    final tokens = ArabicNormalizer.tokenize(trimmed);
    if (tokens.isEmpty) {
      setState(() {
        _inPoemQuery = '';
        _inPoemMatchIndices = const [];
        _inPoemMatchCursor = 0;
      });
      return;
    }
    final matches = <int>[];
    for (final v in poem.verses) {
      final norm = ArabicNormalizer.normalize(v.allHemistichs.join(' '));
      if (tokens.every((t) => norm.contains(t))) {
        matches.add(v.index);
      }
    }
    setState(() {
      _inPoemQuery = trimmed;
      _inPoemMatchIndices = matches;
      _inPoemMatchCursor = 0;
      if (matches.isNotEmpty) {
        _targetScrollIndex = matches.first;
      }
    });
    if (matches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToExactVerseCenter(
          targetIndex: matches.first,
          pulseAfterCenter: true,
        );
      });
    }
  }

  void _jumpToInPoemMatch(int delta) {
    if (_inPoemMatchIndices.isEmpty) return;
    HapticFeedback.selectionClick();
    final len = _inPoemMatchIndices.length;
    final nextCursor = (_inPoemMatchCursor + delta + len) % len;
    final targetVerseIdx = _inPoemMatchIndices[nextCursor];
    setState(() {
      _inPoemMatchCursor = nextCursor;
      _targetScrollIndex = targetVerseIdx;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToExactVerseCenter(
        targetIndex: targetVerseIdx,
        pulseAfterCenter: true,
      );
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _inPoemSearchCtrl.dispose();
    _inPoemSearchFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _readProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.hasClients) {
      final max = _scrollCtrl.position.maxScrollExtent;
      final nextProgress = max > 0
          ? (_scrollCtrl.offset / max).clamp(0.0, 1.0)
          : 0.0;
      if ((nextProgress - _readProgress.value).abs() > 0.008) {
        _readProgress.value = nextProgress;
      }
    }
    if (_selectedIndices.isNotEmpty ||
        _typographyPanelOpen ||
        _inPoemSearchOpen) {
      return;
    }
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
    if (_inPoemSearchOpen) {
      _inPoemSearchFocus.unfocus();
      _inPoemSearchCtrl.clear();
    }
    setState(() {
      _typographyPanelOpen = false;
      _inPoemSearchOpen = false;
      _inPoemQuery = '';
      _inPoemMatchIndices = const [];
      _inPoemMatchCursor = 0;
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
                label: poem.verses.any((v) => v.isMukhammas)
                    ? 'عدد الأبيات المخمّسة'
                    : 'عدد الأبيات',
                value: poem.verses.any((v) => v.isMukhammas)
                    ? '${ArabicNormalizer.toArabicNumber(poem.verses.length)} مخمّساً (خمسة أشطر للبيت)'
                    : '${ArabicNormalizer.toArabicNumber(poem.verses.length)} بيتاً',
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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _ReaderCreateCollectionDialog(),
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
    final hKey =
        '${poem.id}|${settings.poetryFont.id}|${settings.fontSize}|'
        '${settings.verseLayout.index}|${settings.showDiacritics}|'
        '${settings.showVerseNumbers}|${viewportWidth.round()}|'
        '${textScaler.scale(16).toStringAsFixed(2)}';
    final double harmoniousSize;
    if (_cachedHarmoniousKey == hKey && _cachedHarmoniousSize != null) {
      harmoniousSize = _cachedHarmoniousSize!;
    } else {
      harmoniousSize = computePoemHarmoniousFontSize(
        verses: poem.verses,
        font: settings.poetryFont,
        requestedFontSize: settings.fontSize,
        layoutStyle: settings.verseLayout,
        showDiacritics: settings.showDiacritics,
        showVerseNumbers: settings.showVerseNumbers,
        viewportWidth: viewportWidth,
        textScaler: textScaler,
      );
      _cachedHarmoniousKey = hKey;
      _cachedHarmoniousSize = harmoniousSize;
    }

    final interceptBack =
        inSelection || _typographyPanelOpen || _inPoemSearchOpen;

    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_inPoemSearchOpen) {
          _closeInPoemSearch();
        } else if (_typographyPanelOpen) {
          setState(() => _typographyPanelOpen = false);
        } else if (inSelection) {
          setState(() => _selectedIndices.clear());
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Full-bleed Theme-Tinted Arabic Calligraphy Watermark Background
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/calligraphy_bg.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        color: p.accent.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.085
                              : 0.075,
                        ),
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.medium,
                      ),
                      // Subtle editorial radial vignette keeping center verses effortless to read
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.96,
                            colors: [
                              p.canvas.withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.34
                                    : 0.40,
                              ),
                              p.canvas.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
                  cacheExtent: 900,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    _inPoemSearchOpen ? 122 : 66,
                    12,
                    _typographyPanelOpen
                        ? 230
                        : inSelection
                        ? 124
                        : 102,
                  ),
                  itemCount: poem.verses.length + 2,
                  itemBuilder: (context, idx) {
                    // Sleek Open Editorial Micro-Header (Circular Poet Icon + Compact Side Metadata — No Card Box!)
                    if (idx == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => BaytNav.pushEditorial(
                                context,
                                PoetDetailScreen(poetId: poem.poetId),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    // Refined Circular Poet Icon Medallion
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: p.accentSoft,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: p.accent.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 0.9,
                                        ),
                                      ),
                                      child: PoetAvatarIcon(
                                        poetId: poem.poetId,
                                        poetName: poem.poetName,
                                        size: 20,
                                        color: p.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Compact Poet Name + Brief Inline Metadata beside the circular icon
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    poem.poetName,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          AppFonts.ruqaa,
                                                      fontSize: 18.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: p.accent,
                                                      height: 1.22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(
                                                Icons.chevron_left_rounded,
                                                size: 15,
                                                color: p.inkMuted,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _InlineMetaTag(
                                                    icon: Icons
                                                        .hourglass_bottom_rounded,
                                                    label: poem.eraName,
                                                  ),
                                                  _MetaDot(color: p.ornament),
                                                  _InlineMetaTag(
                                                    icon: Icons.waves_rounded,
                                                    label: poem.meterName,
                                                  ),
                                                  _MetaDot(color: p.ornament),
                                                  _InlineMetaTag(
                                                    icon: Icons
                                                        .music_note_outlined,
                                                    label:
                                                        'رويّ (${poem.rhymeName})',
                                                  ),
                                                  _MetaDot(color: p.ornament),
                                                  _InlineMetaTag(
                                                    icon: Icons
                                                        .format_list_numbered_rtl_rounded,
                                                    label:
                                                        poem.verses.any(
                                                          (v) => v.isMukhammas,
                                                        )
                                                        ? '${ArabicNormalizer.toArabicNumber(poem.verses.length)} مخمّساً'
                                                        : '${ArabicNormalizer.toArabicNumber(poem.verses.length)} بيتاً',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const EditorialDivider(
                              verticalPadding: 8,
                              horizontalPadding: 48,
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
                    _lastBuiltVerse = verse.index;
                    final selected = _selectedIndices.contains(verse.index);
                    final isTransientPulse =
                        _transientHighlightIndex == verse.index;
                    final isTargetVerse = _targetScrollIndex == verse.index;

                    return VerseRowWidget(
                      key: isTargetVerse ? _targetVerseKey : null,
                      verse: verse,
                      font: settings.poetryFont,
                      fontSize: harmoniousSize,
                      layoutStyle: settings.verseLayout,
                      showDiacritics: settings.showDiacritics,
                      showVerseNumber: settings.showVerseNumbers,
                      isSelected: selected,
                      isHighlightedVerse:
                          isTransientPulse ||
                          (_inPoemSearchOpen &&
                              _inPoemMatchIndices.contains(verse.index)),
                      // Never split Arabic cursive words with inline TextSpan highlights
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

            // Whisper-Thin Top Reading Progress Hairline (zero-rebuild ValueListenable)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: ValueListenableBuilder<double>(
                  valueListenable: _readProgress,
                  builder: (_, progress, __) => LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      p.accent.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),

            // Immersive Auto-Hiding Top Bar (Correct RTL Back Arrow: east_rounded -> points right!)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top:
                  (_chromeVisible ||
                      inSelection ||
                      _typographyPanelOpen ||
                      _inPoemSearchOpen)
                  ? 0
                  : -140,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 56,
                        child: inSelection
                            ? Row(
                                children: [
                                  IconButton(
                                    tooltip: 'إلغاء التحديد',
                                    onPressed: () => setState(
                                      () => _selectedIndices.clear(),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                  Text(
                                    'محدّد ${ArabicNormalizer.toArabicNumber(_selectedIndices.length)} بيت',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
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
                                      _selectedIndices.length ==
                                              poem.verses.length
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
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.east_rounded),
                                  ),
                                  PoetAvatarIcon(
                                    poetId: poem.poetId,
                                    poetName: poem.poetName,
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
                                    tooltip: _inPoemSearchOpen
                                        ? 'إغلاق البحث داخل القصيدة'
                                        : 'بحث داخل القصيدة',
                                    onPressed: _inPoemSearchOpen
                                        ? _closeInPoemSearch
                                        : _openInPoemSearch,
                                    icon: BaytIconMorph(
                                      icon: Icon(
                                        _inPoemSearchOpen
                                            ? Icons.search_off_rounded
                                            : Icons.search_rounded,
                                        key: ValueKey<bool>(_inPoemSearchOpen),
                                        size: 21,
                                        color: _inPoemSearchOpen
                                            ? p.accent
                                            : p.ink,
                                      ),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            added
                                                ? 'حُفظت القصيدة في المفضلة'
                                                : 'أُزيلت القصيدة من المفضلة',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: BaytIconMorph(
                                      icon: Icon(
                                        isFavPoem
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        key: ValueKey(isFavPoem),
                                        color: isFavPoem ? p.accent : p.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (_inPoemSearchOpen && !inSelection)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: p.accent.withValues(alpha: 0.45),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _inPoemSearchCtrl,
                                    focusNode: _inPoemSearchFocus,
                                    onChanged: _onInPoemQueryChanged,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) {
                                      if (_inPoemMatchIndices.isNotEmpty) {
                                        _jumpToInPoemMatch(1);
                                      }
                                    },
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                    decoration: const InputDecoration(
                                      hintText: 'ابحث في أبيات هذه القصيدة…',
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_inPoemQuery.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _inPoemMatchIndices.isEmpty
                                          ? p.hairline.withValues(alpha: 0.5)
                                          : p.accentSoft,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _inPoemMatchIndices.isEmpty
                                          ? '٠'
                                          : '${ArabicNormalizer.toArabicNumber(_inPoemMatchCursor + 1)} / ${ArabicNormalizer.toArabicNumber(_inPoemMatchIndices.length)}',
                                      style: TextStyle(
                                        fontFamily: AppFonts.ui,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _inPoemMatchIndices.isEmpty
                                            ? p.inkMuted
                                            : p.accent,
                                      ),
                                    ),
                                  ),
                                  if (_inPoemMatchIndices.length > 1) ...[
                                    IconButton(
                                      tooltip: 'الموضع السابق',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
                                      onPressed: () => _jumpToInPoemMatch(-1),
                                      icon: Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 20,
                                        color: p.ink,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'الموضع التالي',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
                                      onPressed: () => _jumpToInPoemMatch(1),
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: p.ink,
                                      ),
                                    ),
                                  ],
                                ],
                                IconButton(
                                  tooltip: 'إغلاق',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  onPressed: _closeInPoemSearch,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: p.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Back-to-Top Pill for long Qasidas (zero scroll rebuilds via ValueListenableBuilder)
            if (poem.verses.length >= 25 &&
                _chromeVisible &&
                !inSelection &&
                !_typographyPanelOpen)
              Positioned(
                bottom: 84,
                left: 16,
                child: SafeArea(
                  top: false,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _readProgress,
                    builder: (_, progress, __) {
                      final show = progress > 0.22;
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: show ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: !show,
                          child: Material(
                            color: p.surfaceElevated.withValues(alpha: 0.94),
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                if (_scrollCtrl.hasClients) {
                                  _scrollCtrl.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 380),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: p.accent.withValues(alpha: 0.4),
                                    width: 0.85,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.vertical_align_top_rounded,
                                      size: 15,
                                      color: p.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'المطلع',
                                      style: TextStyle(
                                        fontFamily: AppFonts.ui,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: p.accent,
                                      ),
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

class _InlineMetaTag extends StatelessWidget {
  const _InlineMetaTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: p.accent),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: p.inkMuted,
            height: 1.25,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '•',
        style: TextStyle(
          fontSize: 10,
          color: color.withValues(alpha: 0.7),
          height: 1.0,
        ),
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
          AnimatedCopyButton(
            tooltip: 'نسخ الأبيات',
            size: 20,
            color: p.ink,
            showLabel: true,
            label: 'نسخ',
            copiedLabel: 'نُسخ',
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            borderRadius: 14,
            onCopy: onCopy,
          ),
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
            BaytIconMorph(
              icon: Icon(
                icon,
                key: ValueKey<String>('${icon.codePoint}_$isHighlighted'),
                size: 20,
                color: color,
              ),
            ),
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

class _ReaderCreateCollectionDialog extends StatefulWidget {
  const _ReaderCreateCollectionDialog();

  @override
  State<_ReaderCreateCollectionDialog> createState() =>
      _ReaderCreateCollectionDialogState();
}

class _ReaderCreateCollectionDialogState
    extends State<_ReaderCreateCollectionDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('مجموعة جديدة'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'اسم المجموعة (مثلاً: عيون الحكمة)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('إنشاء'),
        ),
      ],
    );
  }
}
