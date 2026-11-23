import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bayt_motion.dart';

/// Origin-aware masked ink-ripple transition:
/// - Enters smoothly from the exact tapped trigger point (origin) with 0.95 -> 1.0 scale
/// - Overlaps outgoing page gently receding beneath for tactile spatial depth
/// - Exits 25% faster back into the exact trigger point
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({
    required WidgetBuilder builder,
    Offset? origin,
    super.settings,
  }) : super(
         transitionDuration: const Duration(milliseconds: 420),
         reverseTransitionDuration: const Duration(milliseconds: 300),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final enterCurve = CurvedAnimation(
             parent: animation,
             curve: BaytMotion.easeOut,
             reverseCurve: BaytMotion.exit,
           );

           // Outgoing page recedes gently when another route is pushed over this one
           final secondaryCurve = CurvedAnimation(
             parent: secondaryAnimation,
             curve: BaytMotion.easeOut,
             reverseCurve: BaytMotion.move,
           );
           final outgoingScale = Tween<double>(
             begin: 1.0,
             end: 0.96,
           ).animate(secondaryCurve);
           final outgoingFade = Tween<double>(
             begin: 1.0,
             end: 0.90,
           ).animate(secondaryCurve);

           final revealWidget = AnimatedBuilder(
             animation: enterCurve,
             builder: (context, innerChild) {
               final size = MediaQuery.sizeOf(context);
               final center =
                   origin ?? Offset(size.width * 0.5, size.height * 0.40);
               final maxRadius = _calcMaxRadius(size, center);
               final radius = maxRadius * enterCurve.value;
               final contentScale = 0.955 + (0.045 * enterCurve.value);

               return ClipPath(
                 clipper: _CircleRevealClipper(center: center, radius: radius),
                 child: FadeTransition(
                   opacity: Tween<double>(begin: 0.42, end: 1.0).animate(
                     CurvedAnimation(
                       parent: animation,
                       curve: const Interval(0.0, 0.52, curve: Curves.easeOut),
                     ),
                   ),
                   child: Transform.scale(
                     scale: contentScale,
                     alignment: Alignment.center,
                     child: innerChild,
                   ),
                 ),
               );
             },
             child: child,
           );

           return FadeTransition(
             opacity: outgoingFade,
             child: ScaleTransition(scale: outgoingScale, child: revealWidget),
           );
         },
       );

  static double _calcMaxRadius(Size size, Offset center) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) {
    return oldClipper.radius != radius || oldClipper.center != center;
  }
}

/// Overlapping RTL-native depth-parallax shared-axis transition:
/// - Incoming route glides smoothly with quintic ease-out (340ms) + 0.96 -> 1.0 scale
/// - Outgoing route overlaps beneath with subtle parallax shift + 0.955 depth recede
/// - Exit is 24% faster (260ms) with crisp ease curve and zero bounce
class EditorialSlideRoute<T> extends PageRouteBuilder<T> {
  EditorialSlideRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: BaytMotion.enter,
        reverseTransitionDuration: BaytMotion.exitShort,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final enter = CurvedAnimation(
            parent: animation,
            curve: BaytMotion.easeOut,
            reverseCurve: BaytMotion.exit,
          );
          final exitBeneath = CurvedAnimation(
            parent: secondaryAnimation,
            curve: BaytMotion.easeOut,
            reverseCurve: BaytMotion.move,
          );

          // In RTL Arabic, pushing forward enters from left (-0.18 -> 0.0)
          final incomingSlide = Tween<Offset>(
            begin: const Offset(-0.18, 0.0),
            end: Offset.zero,
          ).animate(enter);
          final incomingScale = Tween<double>(
            begin: 0.965,
            end: 1.0,
          ).animate(enter);
          final incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.58, curve: Curves.easeOut),
              reverseCurve: const Interval(0.45, 1.0, curve: Curves.easeIn),
            ),
          );

          // Beneath route subtly shifts right (+0.055) and scales back to 0.958
          final outgoingSlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0.055, 0.0),
          ).animate(exitBeneath);
          final outgoingScale = Tween<double>(
            begin: 1.0,
            end: 0.958,
          ).animate(exitBeneath);
          final outgoingFade = Tween<double>(
            begin: 1.0,
            end: 0.88,
          ).animate(exitBeneath);

          return SlideTransition(
            position: outgoingSlide,
            child: ScaleTransition(
              scale: outgoingScale,
              child: FadeTransition(
                opacity: outgoingFade,
                child: FadeTransition(
                  opacity: incomingFade,
                  child: SlideTransition(
                    position: incomingSlide,
                    child: ScaleTransition(scale: incomingScale, child: child),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// Centralized navigation helpers that ALWAYS unfocus any active TextField
/// before pushing a new route, and extract exact trigger origins for
/// origin-aware reveal transitions.
class BaytNav {
  BaytNav._();

  static void unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Computes the global center [Offset] of a tapped widget's [BuildContext]
  /// so [pushDrop] enters from and exits back to the exact tapped card.
  static Offset? originFromContext(BuildContext context) {
    final obj = context.findRenderObject();
    if (obj is RenderBox && obj.hasSize) {
      return obj.localToGlobal(obj.size.center(Offset.zero));
    }
    return null;
  }

  static Future<T?> pushDrop<T>(
    BuildContext context,
    Widget page, {
    Offset? origin,
  }) {
    unfocus();
    return Navigator.of(context)
        .push<T>(CircularRevealRoute<T>(builder: (_) => page, origin: origin));
  }

  static Future<T?> pushEditorial<T>(BuildContext context, Widget page) {
    unfocus();
    return Navigator.of(context)
        .push<T>(EditorialSlideRoute<T>(builder: (_) => page));
  }
}
