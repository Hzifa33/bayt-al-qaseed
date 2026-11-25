import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/arabic_normalizer.dart';
import '../../../core/widgets/bayt_ornaments.dart';
import '../../../core/widgets/editorial_divider.dart';
import '../../providers/app_providers.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        await Clipboard.setData(ClipboardData(text: rawUrl));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نُسخ الرابط إلى الحافظة')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نُسخ الرابط إلى الحافظة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final stats = ref.watch(libraryStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق والمطوّر')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // App Showcase Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: p.ornament.withValues(alpha: 0.45),
                width: 1.1,
              ),
            ),
            child: Column(
              children: [
                const BaytEmblem(size: 86),
                const SizedBox(height: 18),
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontFamily: AppFonts.ruqaa,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'الإصدار ${AppConstants.appVersion}',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                ),
                const EditorialDivider(
                  verticalPadding: 18,
                  horizontalPadding: 28,
                ),
                Text(
                  'الموسوعةُ الشعريةُ العربيةُ الشاملة عبر ثلاثةَ عشرَ عصراً أدبياً؛ صُمّمت لتكون رفيقاً هادئاً للقارئ، نقيةً من الإعلانات ومشتّتات القراءة، وتعمل بالكامل دون حاجةٍ إلى اتصال.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: p.inkMuted, height: 1.85),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _MiniMetric(
                      value: ArabicNormalizer.toArabicNumber(stats.poetCount),
                      label: 'شاعراً',
                    ),
                    _MiniMetric(
                      value: ArabicNormalizer.toArabicNumber(stats.poemCount),
                      label: 'قصيدة',
                    ),
                    _MiniMetric(
                      value: ArabicNormalizer.toArabicNumber(stats.verseCount),
                      label: 'بيت شعري',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Developer Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: p.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.architecture_rounded,
                        color: p.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تطوير وتصميم',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: p.accent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConstants.developerHandle,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _LinkTile(
                  icon: Icons.language_rounded,
                  title: 'الموقع الشخصي',
                  subtitle: 'hzifa33.com',
                  onTap: () => _openUrl(context, AppConstants.developerWebsite),
                ),
                const SizedBox(height: 10),
                _LinkTile(
                  icon: Icons.code_rounded,
                  title: 'صفحة التطبيق ومصدره',
                  subtitle: 'github.com/Hzifa33/bayt-al-qaseed',
                  onTap: () => _openUrl(context, AppConstants.repositoryUrl),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          Text(
            '«الشِّعرُ ديوانُ العربِ، وخزانةُ حكمتِهم وبلاغتِهم»',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.scheherazade,
              fontSize: 21,
              color: p.inkMuted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: p.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    subtitle,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 17, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}
