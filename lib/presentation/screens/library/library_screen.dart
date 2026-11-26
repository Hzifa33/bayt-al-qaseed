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

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    String confirmLabel = 'حذف',
  }) async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: p.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _createCollectionDialog() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _CreateCollectionDialog(),
    );
    if (result != null && result.$1.isNotEmpty) {
      try {
        ref
            .read(userDataProvider.notifier)
            .createCollection(result.$1, description: result.$2);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('توجد مجموعةٌ بهذا الاسم مسبقاً')),
          );
        }
      }
    }
  }

  static const MethodChannel _fileChannel = MethodChannel(
    'com.baytalqaseed.app/media',
  );

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

  Future<void> _saveJsonBackupFile() async {
    try {
      final jsonStr = _buildBackupJson();
      final saved = await _fileChannel.invokeMethod<bool>('exportJsonFile', {
        'content': jsonStr,
        'filename': 'bayt_al_qaseed_backup.json',
      });
      if (saved == true && mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حُفظ ملف النسخة الاحتياطية (JSON) بنجاح'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر حفظ الملف: $e')));
      }
    }
  }

  Future<void> _shareJsonBackupFile() async {
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
            .showSnackBar(SnackBar(content: Text('تعذّر مشاركة الملف: $e')));
      }
    }
  }

  Future<void> _pickAndImportJsonFile() async {
    try {
      final rawJson = await _fileChannel.invokeMethod<String>('importJsonFile');
      if (rawJson == null || rawJson.trim().isEmpty) return;
      await _restoreFromJsonString(rawJson);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّرت قراءة ملف JSON: $e')));
      }
    }
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
              'تمت استعادة الإعدادات و${ArabicNormalizer.toArabicNumber(restored)} عنصر من ملف JSON بنجاح',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم نتمكّن من قراءة ملف النسخة الاحتياطية؛ تأكّد من اختيار ملف JSON صالح.',
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
                  Expanded(
                    child: Text(
                      'تصدير واستيراد ملف JSON',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'صدّر مفضلاتك (القصائد، الأبيات، الشعراء، المجموعات) وخيارات التطبيق إلى ملف JSON، أو استعدها في أيّ وقت من ملف JSON محفوظ.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(
                    Icons.save_alt_rounded,
                    color: p.accent,
                    size: 20,
                  ),
                ),
                title: const Text('حفظ ملف النسخة الاحتياطية (JSON)'),
                subtitle: const Text(
                  'حفظ المفضلة وإعدادات التطبيق مباشرة في ملف على الجهاز',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveJsonBackupFile();
                },
              ),
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
                title: const Text('مشاركة ملف النسخة الاحتياطية (JSON)'),
                subtitle: const Text('إرسال ملف JSON إلى تطبيق آخر أو سحابة'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareJsonBackupFile();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: p.accentSoft,
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: p.accent,
                    size: 20,
                  ),
                ),
                title: const Text('استيراد من ملف JSON'),
                subtitle: const Text(
                  'اختيار ملف JSON محفوظ لاستعادة المفضلة وخيارات التطبيق',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndImportJsonFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllBar({
    required String label,
    required VoidCallback onClear,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: onClear,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: Icon(
              Icons.delete_sweep_outlined,
              size: 17,
              color: p.inkMuted,
            ),
            label: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontSize: 12),
            ),
          ),
        ],
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
          // 1. Favorite Poems (with individual + clear-all delete confirmation)
          favPoems.isEmpty
              ? const EmptyStateView(
                  icon: Icons.bookmark_border_rounded,
                  title: 'لا توجد قصائد محفوظة بعد',
                  subtitle: 'اضغط على أيقونة الحفظ داخل أيّ قصيدةٍ لتجدها هنا في متناول يدك.',
                )
              : Column(
                  children: [
                    _buildClearAllBar(
                      label: 'حذف جميع القصائد',
                      onClear: () async {
                        final ok = await _confirmDelete(
                          title: 'حذف القصائد المفضلة',
                          message:
                              'هل تريد إزالة جميع القصائد المفضلة (${ArabicNormalizer.toArabicNumber(favPoems.length)} قصيدة)؟',
                          confirmLabel: 'حذف الكل',
                        );
                        if (ok) {
                          ref
                              .read(userDataProvider.notifier)
                              .clearFavoritePoems();
                        }
                      },
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 102),
                        itemCount: favPoems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final poem = favPoems[i];
                          return InkWell(
                            onTap: () => BaytNav.pushDrop(
                              context,
                              PoemReaderScreen(poemId: poem.id),
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
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
                                          poem.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: AppFonts.scheherazade,
                                            fontSize: 18,
                                            color: p.ink,
                                            height: 1.42,
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
                                    tooltip: 'إزالة من المفضلة',
                                    onPressed: () async {
                                      final ok = await _confirmDelete(
                                        title: 'إزالة القصيدة',
                                        message: 'هل تريد إزالة هذه القصيدة من قائمة المفضلة؟',
                                        confirmLabel: 'إزالة',
                                      );
                                      if (ok) {
                                        ref
                                            .read(userDataProvider.notifier)
                                            .toggleFavoritePoem(poem.id);
                                      }
                                    },
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

          // 2. Favorite Individual Verses (with individual + clear-all delete confirmation)
          userData.favoriteVerses.isEmpty
              ? const EmptyStateView(
                  icon: Icons.format_quote_rounded,
                  title: 'لا توجد أبيات محفوظة بعد',
                  subtitle: 'اضغط مطوّلاً على أيّ بيتٍ داخل القصيدة لحفظه هنا أو تحويله إلى بطاقة.',
                )
              : Column(
                  children: [
                    _buildClearAllBar(
                      label: 'حذف جميع الأبيات',
                      onClear: () async {
                        final ok = await _confirmDelete(
                          title: 'حذف الأبيات المحفوظة',
                          message:
                              'هل تريد حذف جميع الأبيات المحفوظة (${ArabicNormalizer.toArabicNumber(userData.favoriteVerses.length)} بيتاً)؟',
                          confirmLabel: 'حذف الكل',
                        );
                        if (ok) {
                          ref
                              .read(userDataProvider.notifier)
                              .clearFavoriteVerses();
                        }
                      },
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 102),
                        itemCount: userData.favoriteVerses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = userData.favoriteVerses[i];
                          final v = Verse(
                            index: item.verseIndex,
                            sadr: item.sadr,
                            ajuz: item.ajuz,
                          );
                          return Container(
                            padding: const EdgeInsets.all(15),
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
                                    fontSize: 20,
                                    color: p.ink,
                                    height: 1.85,
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
                                        fontSize: 20,
                                        color: p.ink,
                                        height: 1.85,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text('نُسخ البيت'),
                                              ),
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
                                      tooltip: 'حذف البيت',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        final ok = await _confirmDelete(
                                          title: 'حذف البيت المحفوظ',
                                          message: 'هل تريد حذف هذا البيت من مكتبتك؟',
                                        );
                                        if (ok) {
                                          ref
                                              .read(userDataProvider.notifier)
                                              .removeFavoriteVerse(item.id);
                                        }
                                      },
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
                    ),
                  ],
                ),

          // 3. Favorite Poets (with individual + clear-all delete confirmation)
          favPoets.isEmpty
              ? const EmptyStateView(
                  icon: Icons.favorite_border_rounded,
                  title: 'لا يوجد شعراء مفضلون بعد',
                  subtitle: 'أضف شعراءك الأثيرين للوصول السريع إلى دواوينهم.',
                )
              : Column(
                  children: [
                    _buildClearAllBar(
                      label: 'حذف جميع الشعراء',
                      onClear: () async {
                        final ok = await _confirmDelete(
                          title: 'حذف الشعراء المفضلين',
                          message:
                              'هل تريد إزالة جميع الشعراء المفضلين (${ArabicNormalizer.toArabicNumber(favPoets.length)} شاعراً)؟',
                          confirmLabel: 'حذف الكل',
                        );
                        if (ok) {
                          ref
                              .read(userDataProvider.notifier)
                              .clearFavoritePoets();
                        }
                      },
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 102),
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
                            onToggleFavorite: () async {
                              final ok = await _confirmDelete(
                                title: 'إزالة الشاعر',
                                message:
                                    'هل تريد إزالة «${poet.namePlain}» من الشعراء المفضلين؟',
                                confirmLabel: 'إزالة',
                              );
                              if (ok) {
                                ref
                                    .read(userDataProvider.notifier)
                                    .toggleFavoritePoet(poet.id);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

          // 4. Custom Collections (with individual + clear-all delete confirmation)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Expanded(
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
                    if (userData.collections.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'حذف جميع المجموعات',
                        onPressed: () async {
                          final ok = await _confirmDelete(
                            title: 'حذف جميع المجموعات',
                            message:
                                'هل تريد حذف جميع مجموعات القراءة (${ArabicNormalizer.toArabicNumber(userData.collections.length)} مجموعة)؟',
                            confirmLabel: 'حذف الكل',
                          );
                          if (ok) {
                            ref
                                .read(userDataProvider.notifier)
                                .clearAllCollections();
                          }
                        },
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: p.inkMuted,
                        ),
                      ),
                    ],
                  ],
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 102),
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
                              padding: const EdgeInsets.all(14),
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
                                    tooltip: 'حذف المجموعة',
                                    onPressed: () async {
                                      final ok = await _confirmDelete(
                                        title: 'حذف المجموعة',
                                        message:
                                            'هل تريد حذف مجموعة «${col.name}»؟',
                                      );
                                      if (ok) {
                                        ref
                                            .read(userDataProvider.notifier)
                                            .deleteCollection(col.id);
                                      }
                                    },
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

          // 5. Reading History (with individual + clear-all delete confirmation)
          userData.readingHistory.isEmpty
              ? const EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'سجل القراءة فارغ',
                  subtitle: 'القصائد التي تقرأها ستظهر هنا لتعود إليها بيسر.',
                )
              : Column(
                  children: [
                    _buildClearAllBar(
                      label: 'مسح السجل بالكامل',
                      onClear: () async {
                        final ok = await _confirmDelete(
                          title: 'مسح سجل القراءة',
                          message: 'هل تريد مسح جميع القصائد في سجل القراءة؟',
                          confirmLabel: 'مسح الكل',
                        );
                        if (ok) {
                          ref.read(userDataProvider.notifier).clearHistory();
                        }
                      },
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 102),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
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
                                          h.poemTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: AppFonts.scheherazade,
                                            fontSize: 18,
                                            color: p.ink,
                                            height: 1.42,
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
                                  IconButton(
                                    tooltip: 'حذف من السجل',
                                    onPressed: () async {
                                      final ok = await _confirmDelete(
                                        title: 'حذف من السجل',
                                        message: 'هل تريد حذف هذه القصيدة من سجل القراءة؟',
                                      );
                                      if (ok) {
                                        ref
                                            .read(userDataProvider.notifier)
                                            .removeHistoryItem(h.poemId);
                                      }
                                    },
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
        ],
      ),
    );
  }
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء مجموعة جديدة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اسم المجموعة'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(hintText: 'وصف مختصر (اختياري)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            _nameCtrl.text.trim(),
            _descCtrl.text.trim(),
          )),
          child: const Text('إنشاء'),
        ),
      ],
    );
  }
}
