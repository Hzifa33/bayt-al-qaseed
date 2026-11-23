import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/bayt_transitions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/utils/share_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/poet_card.dart';
import '../../../data/models/verse.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_providers.dart';
import '../eras/poet_detail_screen.dart';
import '../reader/poem_reader_screen.dart';
import '../studio/poetry_card_studio_screen.dart';
import 'collection_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCollectionDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء مجموعة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'اسم المجموعة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                hintText: 'وصف مختصر (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        ref
            .read(userDataProvider.notifier)
            .createCollection(
              nameCtrl.text.trim(),
              description: descCtrl.text.trim(),
            );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('توجد مجموعةٌ بهذا الاسم مسبقاً')),
          );
        }
      }
    }
  }

  String _buildBackupJson() {
    final userDataMap = ref.read(userDataProvider.notifier).exportAllUserData();
    final settingsMap = ref.read(readerSettingsProvider.notifier).toMap();
    final payload = {
      'app': AppConstants.appName,
      'version': AppConstants.appVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settingsMap,
      'user_data': userDataMap,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> _exportBackupFile() async {
    try {
      final jsonStr = _buildBackupJson();
      final tmpDir = await getTemporaryDirectory();
      final file = File(path.join(tmpDir.path, 'bayt_al_qaseed_backup.json'));
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text:
            'نسخة احتياطية للمفضلة والإعدادات — تطبيق «${AppConstants.appName}»',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر تصدير الملف: $e')));
      }
    }
  }

  Future<void> _exportFormattedTextAnthology() async {
    final userData = ref.read(userDataProvider);
    final favPoems = ref.read(favoritePoemsListProvider);
    final favPoets = ref.read(favoritePoetsListProvider);
    final buf = StringBuffer()
      ..writeln('مختاراتي من «${AppConstants.appName}»')
      ..writeln('══════════════════════════');

    if (favPoems.isNotEmpty) {
      buf.writeln('\n• القصائد المفضلة (${favPoems.length}):');
      for (final p in favPoems) {
        buf.writeln('  - ${p.title} (${p.poetName})');
      }
    }
    if (userData.favoriteVerses.isNotEmpty) {
      buf.writeln('\n• الأبيات المحفوظة (${userData.favoriteVerses.length}):');
      for (final v in userData.favoriteVerses) {
        buf.writeln('  «${v.sadr}${v.ajuz.isNotEmpty ? ' — ${v.ajuz}' : ''}»');
        buf.writeln('    — ${v.poetName}');
      }
    }
    if (favPoets.isNotEmpty) {
      buf.writeln('\n• الشعراء المفضلون (${favPoets.length}):');
      for (final pt in favPoets) {
        buf.writeln('  - ${pt.namePlain} (العصر ${pt.eraName})');
      }
    }
    await Share.share(buf.toString());
  }

  Future<void> _restoreFromJsonString(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('صيغة غير صالحة');
      }
      final settingsMap = decoded['settings'];
      if (settingsMap is Map<String, dynamic>) {
        ref.read(readerSettingsProvider.notifier).importFromMap(settingsMap);
      }
      final userDataMap = decoded['user_data'];
      var restored = 0;
      if (userDataMap is Map<String, dynamic>) {
        restored = ref
            .read(userDataProvider.notifier)
            .importUserData(userDataMap);
      }
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت استعادة الإعدادات و${ArabicNormalizer.toArabicNumber(restored)} عنصر من المفضلة بنجاح',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم نتمكّن من قراءة النسخة الاحتياطية؛ تأكّد من صحة النص المنسوخ.',
            ),
          ),
        );
      }
    }
  }

  void _openBackupExportSheet() {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.import_export_rounded, size: 22, color: p.accent),
                  const SizedBox(width: 8),
                  Text(
                    'تصدير واستيراد المفضلة والإعدادات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'احفظ نسخةً احتياطية شاملة لقصائدك وأبياتك وشعرائك ومجموعاتك وإعدادات القراءة والخطوط، أو استعدها في أيّ وقت.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(
                    Icons.ios_share_rounded,
                    color: p.accent,
                    size: 19,
                  ),
                ),
                title: const Text('تصدير ملف المفضلة والإعدادات (JSON)'),
                subtitle: const Text(
                  'حفظ أو مشاركة ملف النسخة الاحتياطية الشامل',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportBackupFile();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(
                    Icons.article_outlined,
                    color: p.accent,
                    size: 19,
                  ),
                ),
                title: const Text('تصدير المفضلة كنصٍّ أدبي منسّق'),
                subtitle: const Text(
                  'مشاركة قائمة القصائد والأبيات والشعراء المفضلين كنص',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportFormattedTextAnthology();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(Icons.copy_rounded, color: p.accent, size: 19),
                ),
                title: const Text('نسخ النسخة الاحتياطية إلى الحافظة'),
                subtitle: const Text(
                  'نسخ بيانات المفضلة والإعدادات لاستعادتها لاحقاً',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: _buildBackupJson()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'نُسخت بيانات المفضلة والإعدادات إلى الحافظة',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(
                    Icons.settings_backup_restore_rounded,
                    color: p.accent,
                    size: 20,
                  ),
                ),
                title: const Text('استيراد نسخة احتياطية من الحافظة'),
                subtitle: const Text(
                  'استعادة المفضلة والمجموعات وخيارات التطبيق المنسوخة',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final txt = data?.text?.trim() ?? '';
                  if (txt.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الحافظة فارغة')),
                      );
                    }
                    return;
                  }
                  await _restoreFromJsonString(txt);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final userData = ref.watch(userDataProvider);
    final favPoems = ref.watch(favoritePoemsListProvider);
    final favPoets = ref.watch(favoritePoetsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبتي الأدبية'),
        actions: [
          IconButton(
            tooltip: 'تصدير واستيراد المفضلة والإعدادات',
            onPressed: _openBackupExportSheet,
            icon: Icon(Icons.import_export_rounded, color: p.accent),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: p.accent,
          labelColor: p.accent,
          unselectedLabelColor: p.inkMuted,
          dividerColor: p.hairline,
          tabs: const [
            Tab(
              icon: Icon(Icons.bookmark_outline_rounded, size: 17),
              text: 'القصائد',
            ),
            Tab(
              icon: Icon(Icons.format_quote_rounded, size: 17),
              text: 'الأبيات',
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded, size: 17),
              text: 'الشعراء',
            ),
            Tab(
              icon: Icon(Icons.collections_bookmark_outlined, size: 17),
              text: 'المجموعات',
            ),
            Tab(icon: Icon(Icons.history_rounded, size: 17), text: 'السجل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 1. Favorite Poems
          favPoems.isEmpty
              ? const EmptyStateView(
                  icon: Icons.bookmark_border_rounded,
                  title: 'لا توجد قصائد محفوظة بعد',
                  subtitle: 'اضغط على أيقونة الحفظ داخل أيّ قصيدةٍ لتجدها هنا في متناول يدك.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
                  itemCount: favPoems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final poem = favPoems[i];
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
                                      height: 1.5,
                                    ),
                                  ),
                                  Text(
                                    '${poem.poetName}  •  بحر ${poem.meterName}  •  ${ArabicNormalizer.toArabicNumber(poem.verseCount)} بيتاً',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'إزالة',
                              onPressed: () => ref
                                  .read(userDataProvider.notifier)
                                  .toggleFavoritePoem(poem.id),
                              icon: Icon(
                                Icons.bookmark_remove_outlined,
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

          // 2. Favorite Individual Verses
          userData.favoriteVerses.isEmpty
              ? const EmptyStateView(
                  icon: Icons.format_quote_rounded,
                  title: 'لا توجد أبيات محفوظة بعد',
                  subtitle: 'اضغط مطوّلاً على أيّ بيتٍ داخل القصيدة لحفظه هنا أو تحويله إلى بطاقة.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
                  itemCount: userData.favoriteVerses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = userData.favoriteVerses[i];
                    final v = Verse(
                      index: item.verseIndex,
                      sadr: item.sadr,
                      ajuz: item.ajuz,
                    );
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.sadr,
                            style: TextStyle(
                              fontFamily: AppFonts.scheherazade,
                              fontSize: 21,
                              color: p.ink,
                              height: 1.9,
                            ),
                          ),
                          if (item.ajuz.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Text(
                                item.ajuz,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: AppFonts.scheherazade,
                                  fontSize: 21,
                                  color: p.ink,
                                  height: 1.9,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => BaytNav.pushDrop(
                                    context,
                                    PoemReaderScreen(
                                      poemId: item.poemId,
                                      initialVerseIndex: item.verseIndex,
                                    ),
                                  ),
                                  child: Text(
                                    '— ${item.poetName}',
                                    style: TextStyle(
                                      fontFamily: AppFonts.ui,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: p.accent,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'نسخ البيت',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: ShareFormatter.formatVerses(
                                        verses: [v],
                                        poetName: item.poetName,
                                      ),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('نُسخ البيت')),
                                  );
                                },
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: p.inkMuted,
                                ),
                              ),
                              IconButton(
                                tooltip: 'تصميم بطاقة',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => BaytNav.pushDrop(
                                  context,
                                  PoetryCardStudioScreen(
                                    verses: [v],
                                    poetName: item.poetName,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.brush_outlined,
                                  size: 18,
                                  color: p.accent,
                                ),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => ref
                                    .read(userDataProvider.notifier)
                                    .removeFavoriteVerse(item.id),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: p.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

          // 3. Favorite Poets
          favPoets.isEmpty
              ? const EmptyStateView(
                  icon: Icons.favorite_border_rounded,
                  title: 'لا يوجد شعراء مفضلون بعد',
                  subtitle: 'أضف شعراءك الأثيرين للوصول السريع إلى دواوينهم.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 102),
                  itemCount: favPoets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final poet = favPoets[i];
                    return PoetCard(
                      poet: poet,
                      showEra: true,
                      isFavorite: true,
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

          // 4. Custom Collections
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _createCollectionDialog,
                    icon: Icon(
                      Icons.create_new_folder_outlined,
                      color: p.accent,
                    ),
                    label: Text(
                      'إنشاء مجموعة قراءة جديدة',
                      style: TextStyle(color: p.accent),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: userData.collections.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.collections_bookmark_outlined,
                        title: 'أنشئ مجموعاتك الخاصة',
                        subtitle: 'نظّم القصائد حسب الموضوع أو المعنى (مثل: الحكمة، الرثاء، الأندلسيات).',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
                        itemCount: userData.collections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final col = userData.collections[i];
                          return InkWell(
                            onTap: () => BaytNav.pushEditorial(
                              context,
                              CollectionDetailScreen(collection: col),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: p.surfaceElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: p.hairline),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_special_outlined,
                                    color: p.accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          col.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        if (col.description.isNotEmpty)
                                          Text(
                                            col.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        Text(
                                          '${ArabicNormalizer.toArabicNumber(col.poemCount)} قصيدة',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: p.accent),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => ref
                                        .read(userDataProvider.notifier)
                                        .deleteCollection(col.id),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
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
              ),
            ],
          ),

          // 5. Reading History
          userData.readingHistory.isEmpty
              ? const EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'سجل القراءة فارغ',
                  subtitle: 'القصائد التي تقرأها ستظهر هنا لتعود إليها بيسر.',
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            ref.read(userDataProvider.notifier).clearHistory(),
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          size: 18,
                          color: p.inkMuted,
                        ),
                        label: Text(
                          'مسح السجل',
                          style: TextStyle(color: p.inkMuted),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                        itemCount: userData.readingHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final h = userData.readingHistory[i];
                          return InkWell(
                            onTap: () => BaytNav.pushDrop(
                              context,
                              PoemReaderScreen(
                                poemId: h.poemId,
                                initialVerseIndex: h.lastVerseIndex,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: p.surfaceElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: p.hairline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.poemTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.scheherazade,
                                      fontSize: 20,
                                      color: p.ink,
                                      height: 1.5,
                                    ),
                                  ),
                                  Text(
                                    '${h.poetName}  •  بحر ${h.meterName}  •  ${ArabicNormalizer.toArabicNumber(h.verseCount)} بيتاً',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
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
        ],
      ),
    );
  }
}
