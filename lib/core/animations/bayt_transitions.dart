import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Calm organic water-drop / ink-ripple circular reveal transition.
///
/// Expands smoothly from the tapped screen focal point (or top-center parchment
/// origin when omitted) with a gentle decelerating curve suited for literary reading.
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({
    required WidgetBuilder builder,
    Offset? origin,
    super.settings,
  }) : super(
         transitionDuration: const Duration(milliseconds: 520),
         reverseTransitionDuration: const Duration(milliseconds: 360),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutQuart,
             reverseCurve: Curves.easeInCubic,
           );

           return AnimatedBuilder(
             animation: curved,
             builder: (context, innerChild) {
               final size = MediaQuery.sizeOf(context);
               final center =
                   origin ?? Offset(size.width * 0.5, size.height * 0.38);
               final maxRadius = _calcMaxRadius(size, center);
               final radius = maxRadius * curved.value;

               return ClipPath(
                 clipper: _CircleRevealClipper(center: center, radius: radius),
                 child: FadeTransition(
                   opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
                     CurvedAnimation(
                       parent: animation,
                       curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
                     ),
                   ),
                   child: innerChild,
                 ),
               );
             },
             child: child,
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

/// Fluid RTL-native shared-axis editorial glide + subtle depth scale transition.
class EditorialSlideRoute<T> extends PageRouteBuilder<T> {
  EditorialSlideRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInCubic,
          );

          // In RTL Arabic, pushing forward glides naturally from left (-0.16 -> 0.0)
          final slide = Tween<Offset>(
            begin: const Offset(-0.14, 0.0),
            end: Offset.zero,
          ).animate(curved);

          final scale = Tween<double>(begin: 0.975, end: 1.0).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
      );
}

/// Centralized navigation helpers that ALWAYS unfocus any active TextField
/// before pushing a new route, preventing the keyboard from unexpectedly
/// reopening when returning to search or filter screens.
class BaytNav {
  BaytNav._();

  static void unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
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
