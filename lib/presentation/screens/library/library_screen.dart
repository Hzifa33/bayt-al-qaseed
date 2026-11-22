import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/utils/share_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/verse.dart';
import '../../providers/app_providers.dart';
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
            const SnackBar(content: Text('توجد مجموعة بهذا الاسم مسبقاً')),
          );
        }
      }
    }
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
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: p.accent,
          labelColor: p.accent,
          unselectedLabelColor: p.inkMuted,
          dividerColor: p.hairline,
          tabs: const [
            Tab(text: 'القصائد'),
            Tab(text: 'الأبيات'),
            Tab(text: 'الشعراء'),
            Tab(text: 'المجموعات'),
            Tab(text: 'السجل'),
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
                  title: 'لا توجد قصائد مفضلة بعد',
                  subtitle:
                      'اضغط على أيقونة الحفظ داخل أي قصيدة لتجدها هنا فوراً.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  itemCount: favPoems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final poem = favPoems[i];
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PoemReaderScreen(poemId: poem.id),
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
                  subtitle: 'اضغط مطوّلاً على أي بيت داخل القصيدة لحفظه هنا أو تحويله لبطاقة.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
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
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PoemReaderScreen(
                                        poemId: item.poemId,
                                        initialVerseIndex: item.verseIndex,
                                      ),
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
                                    const SnackBar(
                                      content: Text('تم نسخ البيت'),
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
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PoetryCardStudioScreen(
                                      verses: [v],
                                      poetName: item.poetName,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.palette_outlined,
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
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  itemCount: favPoets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final poet = favPoets[i];
                    return InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PoetDetailScreen(poetId: poet.id),
                        ),
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
                                Icons.favorite_rounded,
                                color: p.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        subtitle: 'نظّم القصائد حسب الموضوع أو الحالة الشعورية (مثل: الحكمة، الرثاء، الأندلسيات).',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                        itemCount: userData.collections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final col = userData.collections[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CollectionDetailScreen(collection: col),
                              ),
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
                  subtitle: 'القصائد التي تقرأها ستظهر هنا لتعود إليها بسهولة.',
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
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        itemCount: userData.readingHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final h = userData.readingHistory[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PoemReaderScreen(
                                  poemId: h.poemId,
                                  initialVerseIndex: h.lastVerseIndex,
                                ),
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
