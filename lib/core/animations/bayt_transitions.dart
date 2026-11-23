import 'package:flutter/material.dart';

import 'bayt_motion.dart';

/// Featherlight, GPU-composited Poem Reader transition.
///
/// Replaces heavy ClipPath reveals with a calm, ultra-smooth 240ms fade-through
/// + subtle vertical/scale settle (0.982 -> 1.0) so transitioning from a poet's
/// Diwan or search result into a poem feels effortless and completely free of
/// visual anxiety or frame drops.
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({
    required WidgetBuilder builder,
    Offset? origin,
    super.settings,
  }) : super(
         transitionDuration: const Duration(milliseconds: 245),
         reverseTransitionDuration: const Duration(milliseconds: 185),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final enter = CurvedAnimation(
             parent: animation,
             curve: BaytMotion.easeOut,
             reverseCurve: BaytMotion.exit,
           );

           final slide = Tween<Offset>(
             begin: const Offset(0.0, 0.028),
             end: Offset.zero,
           ).animate(enter);

           final scale = Tween<double>(begin: 0.984, end: 1.0).animate(enter);

           return FadeTransition(
             opacity: enter,
             child: SlideTransition(
               position: slide,
               child: ScaleTransition(scale: scale, child: child),
             ),
           );
         },
       );
}

/// Calm RTL shared-axis glide transition for navigating between screens:
/// - Smooth 250ms ease-out entrance with subtle -0.07 horizontal glide
/// - Fast 190ms exit with zero disorienting background motion
class EditorialSlideRoute<T> extends PageRouteBuilder<T> {
  EditorialSlideRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 190),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final enter = CurvedAnimation(
            parent: animation,
            curve: BaytMotion.easeOut,
            reverseCurve: BaytMotion.exit,
          );

          final incomingSlide = Tween<Offset>(
            begin: const Offset(-0.07, 0.0),
            end: Offset.zero,
          ).animate(enter);

          return FadeTransition(
            opacity: enter,
            child: SlideTransition(position: incomingSlide, child: child),
          );
        },
      );
}

/// Centralized navigation helpers that ALWAYS unfocus any active TextField
/// before pushing a new route.
class BaytNav {
  BaytNav._();

  static void unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

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
