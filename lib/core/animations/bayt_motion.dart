import 'package:flutter/material.dart';

/// Snappy, modern editorial motion tokens & micro-interaction primitives for «بيت القصيد».
///
/// Tuned for crisp 120fps responsiveness:
/// - Fast cubic ease-out entrances with zero sluggish asymptotic tail
/// - 25% shorter exits so back navigation feels instantaneous
/// - Tactile 0.975 press feedback
/// - Lightweight 16ms viewport stagger capped at 5 items
class BaytMotion {
  BaytMotion._();

  /// Crisp decelerating ease-out curve for entrances & reveals.
  static const Curve easeOut = Curves.easeOutCubic;

  /// Balanced ease-in-out curve for positional moves & layout morphs.
  static const Curve move = Curves.easeInOutCubic;

  /// Fast accelerating curve for exits.
  static const Curve exit = Curves.easeInCubic;

  static const Duration fast = Duration(milliseconds: 110);
  static const Duration popover = Duration(milliseconds: 145);
  static const Duration enter = Duration(milliseconds: 180);
  static const Duration exitShort = Duration(milliseconds: 135);
}

/// Tactile press-feedback wrapper scaling cleanly to 0.975 on press down.
class BaytPressable extends StatefulWidget {
  const BaytPressable({
    super.key,
    required this.child,
    this.scaleDown = 0.975,
    this.enabled = true,
  });

  final Widget child;
  final double scaleDown;
  final bool enabled;

  @override
  State<BaytPressable> createState() => _BaytPressableState();
}

class _BaytPressableState extends State<BaytPressable> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!widget.enabled || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 70)
            : const Duration(milliseconds: 120),
        curve: BaytMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Ultra-light 16ms staggered entrance capped to the top 5 viewport rows.
class BaytStaggeredItem extends StatefulWidget {
  const BaytStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggerItems = 5,
  });

  final int index;
  final Widget child;
  final int maxStaggerItems;

  @override
  State<BaytStaggeredItem> createState() => _BaytStaggeredItemState();
}

class _BaytStaggeredItemState extends State<BaytStaggeredItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (widget.index < widget.maxStaggerItems) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
      );
      _ctrl = ctrl;
      final curved = CurvedAnimation(parent: ctrl, curve: BaytMotion.easeOut);
      _fade = curved;
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curved);

      final delayMs = widget.index * 16;
      if (delayMs == 0) {
        ctrl.forward();
      } else {
        Future.delayed(Duration(milliseconds: delayMs), () {
          if (mounted) ctrl.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    final slide = _slide;
    if (fade == null || slide == null) return widget.child;

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

/// Crisp crossfade + subtle scale morph for toggling icons.
class BaytIconMorph extends StatelessWidget {
  const BaytIconMorph({
    super.key,
    required this.icon,
    this.duration = const Duration(milliseconds: 135),
  });

  final Widget icon;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: BaytMotion.easeOut,
      switchOutCurve: BaytMotion.exit,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(anim),
            child: child,
          ),
        );
      },
      child: icon,
    );
  }
}
