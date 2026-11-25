import 'package:flutter/material.dart';

import 'bayt_motion.dart';

/// Ultra-crisp Poem Reader transition: 165ms fade + subtle micro-scale (0.988 -> 1.0)
/// with fast 125ms dismissal so opening and closing poems feels instantaneous.
class CircularRevealRoute<T> extends PageRouteBuilder<T> {
  CircularRevealRoute({
    required WidgetBuilder builder,
    Offset? origin,
    super.settings,
  }) : super(
         transitionDuration: const Duration(milliseconds: 165),
         reverseTransitionDuration: const Duration(milliseconds: 125),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final enter = CurvedAnimation(
             parent: animation,
             curve: BaytMotion.easeOut,
             reverseCurve: BaytMotion.exit,
           );

           final scale = Tween<double>(begin: 0.988, end: 1.0).animate(enter);

           return FadeTransition(
             opacity: enter,
             child: ScaleTransition(scale: scale, child: child),
           );
         },
       );
}

/// Snappy RTL horizontal drill-down transition for directories (Eras, Poets, Themes, Feelings):
/// 180ms enter / 135ms exit with crisp -0.14 horizontal glide.
class EditorialSlideRoute<T> extends PageRouteBuilder<T> {
  EditorialSlideRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 135),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final enter = CurvedAnimation(
            parent: animation,
            curve: BaytMotion.easeOut,
            reverseCurve: BaytMotion.exit,
          );

          final incomingSlide = Tween<Offset>(
            begin: const Offset(-0.14, 0.0),
            end: Offset.zero,
          ).animate(enter);

          return FadeTransition(
            opacity: enter,
            child: SlideTransition(position: incomingSlide, child: child),
          );
        },
      );
}

/// Crisp upward modal glide for utility & creative screens (About, Card Studio):
/// 185ms enter / 140ms exit with gentle 0.07 vertical rise.
class ModalRiseRoute<T> extends PageRouteBuilder<T> {
  ModalRiseRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 185),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final enter = CurvedAnimation(
            parent: animation,
            curve: BaytMotion.easeOut,
            reverseCurve: BaytMotion.exit,
          );

          final rise = Tween<Offset>(
            begin: const Offset(0.0, 0.07),
            end: Offset.zero,
          ).animate(enter);

          return FadeTransition(
            opacity: enter,
            child: SlideTransition(position: rise, child: child),
          );
        },
      );
}

/// Centralized navigation helpers with purposeful, distinct transitions per screen type.
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

  /// Fast reader transition for opening poems.
  static Future<T?> pushDrop<T>(
    BuildContext context,
    Widget page, {
    Offset? origin,
  }) {
    unfocus();
    return Navigator.of(context)
        .push<T>(CircularRevealRoute<T>(builder: (_) => page, origin: origin));
  }

  /// Snappy RTL horizontal slide for drilling into directories & details.
  static Future<T?> pushEditorial<T>(BuildContext context, Widget page) {
    unfocus();
    return Navigator.of(context)
        .push<T>(EditorialSlideRoute<T>(builder: (_) => page));
  }

  /// Crisp upward sheet glide for About, Card Studio, and modal-like views.
  static Future<T?> pushModal<T>(BuildContext context, Widget page) {
    unfocus();
    return Navigator.of(context)
        .push<T>(ModalRiseRoute<T>(builder: (_) => page));
  }
}
