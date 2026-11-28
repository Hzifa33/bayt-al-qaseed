import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/arabic_normalizer.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  double _progress = 0.04;
  String _status = 'تهيئة ديوان «بيت القصيد»…';
  bool _isExtracting = false;
  int _bytesWritten = 0;
  int _expectedTotalBytes = 0;
  int? _etaSeconds;
  String? _error;
  InsufficientStorageException? _storageError;
  bool _isBootstrapping = false;

  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns from system settings after freeing up storage,
    // automatically refresh free space and resume if enough space is now free.
    if (state == AppLifecycleState.resumed &&
        _storageError != null &&
        !_isBootstrapping) {
      _checkAndMaybeAutoResume();
    }
  }

  Future<void> _checkAndMaybeAutoResume() async {
    final check = await PoetryDatabase.checkStorageSpace();
    if (!mounted || check == null) return;
    if (check.hasEnoughSpace) {
      _bootstrap();
    } else {
      setState(() {
        _storageError = InsufficientStorageException(
          requiredBytes: check.requiredBytes,
          availableBytes: check.availableBytes,
        );
      });
    }
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping) return;
    _isBootstrapping = true;

    setState(() {
      _error = null;
      _storageError = null;
      _progress = 0.04;
      _isExtracting = false;
      _bytesWritten = 0;
      _expectedTotalBytes = 0;
      _etaSeconds = null;
      _status = 'تهيئة الموسوعة الشعرية…';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      ref.read(readerSettingsProvider.notifier).hydrate(prefs);

      final userDb = await UserDatabase.openDefault();
      final poetryDb = await PoetryDatabase.openBundled(
        onProgress: (info) {
          if (!mounted) return;
          setState(() {
            _progress = info.fraction.clamp(0.02, 1.0);
            _status = info.status;
            _isExtracting = info.isExtracting;
            _bytesWritten = info.bytesWritten;
            _expectedTotalBytes = info.expectedTotalBytes;
            _etaSeconds = info.etaSeconds;
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
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const MainShellScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );
    } on InsufficientStorageException catch (e) {
      if (!mounted) return;
      setState(() {
        _storageError = e;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _storageError = null;
        _error = 'تعذّرت تهيئة الديوان:\n$e';
      });
    } finally {
      _isBootstrapping = false;
    }
  }

  String _formatExtractionDetail() {
    final parts = <String>[];
    if (_bytesWritten > 0) {
      final writtenMb = (_bytesWritten / (1024 * 1024)).round();
      final totalMb = _expectedTotalBytes > 0
          ? (_expectedTotalBytes / (1024 * 1024)).round()
          : 0;
      if (totalMb > 0 && writtenMb <= totalMb) {
        parts.add(
          '${ArabicNormalizer.toArabicNumber(writtenMb)} / ${ArabicNormalizer.toArabicNumber(totalMb)} م.ب',
        );
      } else {
        parts.add('${ArabicNormalizer.toArabicNumber(writtenMb)} م.ب');
      }
    }
    if (_etaSeconds != null && _etaSeconds! > 0) {
      final secs = _etaSeconds!;
      if (secs >= 60) {
        final mins = secs ~/ 60;
        final rem = secs % 60;
        parts.add(
          'متبقي ~${ArabicNormalizer.toArabicNumber(mins)} د ${ArabicNormalizer.toArabicNumber(rem)} ث',
        );
      } else {
        parts.add('متبقي ~${ArabicNormalizer.toArabicNumber(secs)} ثانية');
      }
    }
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (_progress * 100).round().clamp(1, 100);
    final detailLine = _isExtracting ? _formatExtractionDetail() : '';

    return Scaffold(
      backgroundColor: p.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Whisper-soft Arabic Calligraphy Watermark matching the app & site
          IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.055 : 0.042,
              child: Image.asset(
                'assets/images/calligraphy_bg.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Warm radial canvas wash focusing attention on the emblem
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.18),
                  radius: 0.92,
                  colors: [
                    p.accent.withValues(alpha: isDark ? 0.08 : 0.055),
                    p.canvas.withValues(alpha: 0.78),
                    p.canvas,
                  ],
                  stops: const [0.0, 0.56, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _enterCtrl,
                curve: Curves.easeOutCubic,
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Emblem with gentle golden ambient breathing halo
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, child) {
                            final glow = 0.14 + (_pulseCtrl.value * 0.14);
                            final spread = 14.0 + (_pulseCtrl.value * 10.0);
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: p.accent.withValues(alpha: glow),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.accent.withValues(
                                      alpha: glow * 0.75,
                                    ),
                                    blurRadius: spread * 1.8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: const BaytEmblem(size: 86),
                        ),
                        const SizedBox(height: 24),

                        // App Title in Aref Ruqaa calligraphy
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
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: p.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '«الشِّعرُ ديوانُ العربِ، وخزانةُ حكمتِهم وبلاغتِهم»',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.scheherazade,
                            fontSize: 17.5,
                            color: p.inkMuted,
                            height: 1.5,
                          ),
                        ),

                        const EditorialDivider(
                          verticalPadding: 22,
                          horizontalPadding: 34,
                        ),

                        if (_storageError != null) ...[
                          _buildInsufficientStorageCard(context, _storageError!),
                        ] else if (_error != null) ...[
                          _buildGenericErrorCard(context, _error!),
                        ] else ...[
                          // Refined Editorial Progress Card with live MB & ETA
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: p.surfaceElevated.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: p.hairline,
                                width: 0.95,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _status,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: p.ink,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12.2,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${ArabicNormalizer.toArabicNumber(pct)}٪',
                                      style: TextStyle(
                                        fontFamily: AppFonts.ui,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.accent,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(end: _progress),
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: val,
                                        minHeight: 7,
                                        backgroundColor: p.hairline,
                                        valueColor: AlwaysStoppedAnimation(
                                          p.accent,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (detailLine.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    detailLine,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: p.inkMuted,
                                          fontSize: 11,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                                if (_isExtracting) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: p.accent.withValues(alpha: 0.22),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.wifi_off_rounded,
                                          size: 14,
                                          color: p.accent,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'فكّ ضغط محلي بالكامل دون إنترنت (مرّة واحدة فقط)',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: p.ink,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 10.8,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Subtle Corpus Preview Strip
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SplashBadge(label: '٥٫٦ مليون بيت'),
                              SizedBox(width: 6),
                              _SplashBadge(label: '٣٣٨ ألف قصيدة'),
                              SizedBox(width: 6),
                              _SplashBadge(label: '١٧٬٢٤٤ شاعراً'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientStorageCard(
    BuildContext context,
    InsufficientStorageException err,
  ) {
    final p = context.palette;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sd_storage_outlined,
              color: cs.error,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'المساحة التخزينية غير كافية',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: p.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يحتاج فك ضغط الموسوعة الشعرية إلى ${ArabicNormalizer.toArabicNumber(err.requiredMb)} م.ب من المساحة الحرّة، بينما المتوفر حالياً ${ArabicNormalizer.toArabicNumber(err.availableMb)} م.ب فقط.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: p.inkMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.hairline, width: 0.8),
            ),
            child: Text(
              'يرجى تفريغ ${ArabicNormalizer.toArabicNumber(err.missingMb)} م.ب على الأقل ثم الضغط على «استئناف».\nلم تتضرر قاعدة البيانات ولا بياناتك المحفوظة.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: p.ink,
                height: 1.5,
                fontSize: 11.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('استئناف فك الضغط'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericErrorCard(BuildContext context, String message) {
    final p = context.palette;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.error),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _SplashBadge extends StatelessWidget {
  const _SplashBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.hairline, width: 0.8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: p.inkMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
