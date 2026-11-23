import 'package:flutter/material.dart';

/// Motion design tokens & micro-interaction primitives for «بيت القصيد».
///
/// Built on refined editorial motion physics:
/// - Smooth quintic ease-out entrances (zero jarring bounce on everyday UI)
/// - 20-25% shorter exits for crisp responsiveness
/// - Tactile 0.97 press scale (never tweens while held)
/// - 30ms staggered viewport entrances (capped so deep scrolling never stalls)
/// - Popovers starting at 0.95 scale at 180-220ms
class BaytMotion {
  BaytMotion._();

  /// Smooth decelerating ease-out curve for entrances & reveals.
  static const Curve easeOut = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Balanced ease-in-out curve for positional moves & layout morphs.
  static const Curve move = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Crisp accelerating curve for exits (paired with 20% shorter durations).
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration popover = Duration(milliseconds: 210);
  static const Duration enter = Duration(milliseconds: 340);
  static const Duration exitShort = Duration(milliseconds: 260);
}

/// Tactile press-feedback wrapper scaling cleanly to 0.97 on press down
/// without bouncing or tweening while held.
class BaytPressable extends StatefulWidget {
  const BaytPressable({
    super.key,
    required this.child,
    this.scaleDown = 0.97,
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
            ? const Duration(milliseconds: 95)
            : const Duration(milliseconds: 175),
        curve: BaytMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Gentle 30ms staggered list row entrance capped to the initial viewport rows
/// so deep scrolling through thousands of poems remains 100% instantaneous.
class BaytStaggeredItem extends StatefulWidget {
  const BaytStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggerItems = 8,
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
        duration: const Duration(milliseconds: 280),
      );
      _ctrl = ctrl;
      final curved = CurvedAnimation(parent: ctrl, curve: BaytMotion.easeOut);
      _fade = curved;
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.055),
        end: Offset.zero,
      ).animate(curved);

      final delayMs = widget.index * 30;
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

/// Smooth crossfade + subtle scale morph for toggling icons (search/close,
/// favorite/unfavorite, bookmark/unbookmark) with confirmation pulse on active.
class BaytIconMorph extends StatelessWidget {
  const BaytIconMorph({
    super.key,
    required this.icon,
    this.duration = const Duration(milliseconds: 200),
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
            scale: Tween<double>(begin: 0.84, end: 1.0).animate(anim),
            child: child,
          ),
        );
      },
      child: icon,
    );
  }
}
