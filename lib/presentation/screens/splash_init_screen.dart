import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bayt_ornaments.dart';
import '../../core/widgets/editorial_divider.dart';
import '../../data/datasources/poetry_database.dart';
import '../../data/datasources/user_database.dart';
import '../providers/database_providers.dart';
import '../providers/settings_provider.dart';
import 'main_shell_screen.dart';

class SplashInitScreen extends ConsumerStatefulWidget {
  const SplashInitScreen({super.key});

  @override
  ConsumerState<SplashInitScreen> createState() => _SplashInitScreenState();
}

class _SplashInitScreenState extends ConsumerState<SplashInitScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.06;
  String _status = 'تهيئة ديوان «بيت القصيد»…';
  String? _error;

  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _error = null;
      _progress = 0.08;
      _status = 'تهيئة ديوان «بيت القصيد»…';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      ref.read(readerSettingsProvider.notifier).hydrate(prefs);

      final userDb = await UserDatabase.openDefault();
      final poetryDb = await PoetryDatabase.openBundled(
        onProgress: (p, msg) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _status = msg;
          });
        },
      );

      ref.read(appServicesProvider.notifier).state = AppServices(
        poetryDb: poetryDb,
        userDb: userDb,
        prefs: prefs,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 480),
          pageBuilder: (_, __, ___) => const MainShellScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّرت تهيئة الديوان:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BaytEmblem(size: 88),
                  const SizedBox(height: 26),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppConstants.appName,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.ruqaa,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (AppConstants.isExpanded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                        'النسخة الموسّعة',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'ديوانُ الشعر العربي من الجاهلية إلى العصر الحديث',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: p.inkMuted, fontSize: 13.5),
                  ),
                  const EditorialDivider(
                    verticalPadding: 24,
                    horizontalPadding: 42,
                  ),
                  if (_error == null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 4,
                        backgroundColor: p.hairline,
                        valueColor: AlwaysStoppedAnimation(p.accent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _bootstrap,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
