import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bayt_ornaments.dart';

/// Displays a refined, one-time announcement dialog inside the Standard Edition
/// introducing users to the standalone Expanded Edition («النسخة الموسّعة»).
class ExpandedEditionIntroDialog extends StatelessWidget {
  const ExpandedEditionIntroDialog({super.key});

  static const _prefKey = 'seen_expanded_edition_intro_v1';

  /// Shows the modal once in the Standard Edition and persists dismissal immediately.
  static Future<void> showOnceIfNeeded(BuildContext context) async {
    if (AppConstants.isExpanded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) == true) return;
      await prefs.setBool(_prefKey, true);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const ExpandedEditionIntroDialog(),
      );
    } catch (_) {
      // Never interrupt startup if preferences are unavailable.
    }
  }

  Future<void> _openDownloadPage(BuildContext context) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(AppConstants.expandedReleaseUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.accent.withValues(alpha: 0.35), width: 1.1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BaytEmblem(size: 62, showExpandedBadge: true),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: p.accent.withValues(alpha: 0.35),
                    width: 0.85,
                  ),
                ),
                child: Text(
                  'إصدارٌ مستقلٌّ جديد',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تعرّف على النسخة الموسّعة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ruqaa,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'إن كنتَ تطمح إلى أوسع مكتبةٍ شعريةٍ عربيةٍ تعمل دون إنترنت، فقد أطلقنا نسخةً موسّعةً مستقلّةً من «بيت القصيد» بعلامة (+) على الأيقونة.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: p.inkMuted, height: 1.65, fontSize: 12.8),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  children: [
                    _FeatureRow(
                      icon: Icons.auto_stories_outlined,
                      text: 'أكثر من ٥٫٦ مليون بيتٍ و٣٣٨ ألف قصيدة',
                      accent: p.accent,
                      ink: p.ink,
                    ),
                    const SizedBox(height: 8),
                    _FeatureRow(
                      icon: Icons.groups_outlined,
                      text: '١٧٬٢٤٤ شاعراً عبر ١٣ عصراً أدبياً',
                      accent: p.accent,
                      ink: p.ink,
                    ),
                    const SizedBox(height: 8),
                    _FeatureRow(
                      icon: Icons.psychology_outlined,
                      text: 'مستكشف ١٢٧ شعوراً و١٠ أغراضٍ شعرية',
                      accent: p.accent,
                      ink: p.ink,
                    ),
                    const SizedBox(height: 8),
                    _FeatureRow(
                      icon: Icons.install_mobile_outlined,
                      text: 'تُثبّت بجانب هذه النسخة دون أي تداخل',
                      accent: p.accent,
                      ink: p.ink,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openDownloadPage(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 19),
                  label: const Text(
                    'استعراض وتحميل النسخة الموسّعة',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'المتابعة في النسخة القياسية',
                    style: TextStyle(color: p.inkMuted, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.accent,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ink, fontSize: 12.2),
          ),
        ),
      ],
    );
  }
}
