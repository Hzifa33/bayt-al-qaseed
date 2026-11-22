import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
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
  double _progress = 0.05;
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
      _status = 'تهيئة التفضيلات…';
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
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => const MainShellScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تهيئة قاعدة البيانات:\n$e');
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
                  // Minimal Neo-Heritage Octagonal Emblem
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: p.surfaceElevated,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: p.ornament.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 38,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontFamily: AppFonts.ruqaa,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'موسوعة الشعر العربي من الجاهلية إلى العصر الحديث',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: p.inkMuted, fontSize: 13.5),
                  ),
                  const EditorialDivider(
                    verticalPadding: 24,
                    horizontalPadding: 40,
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
