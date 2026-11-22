import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Subtle Neo-Heritage editorial divider with a minimal diamond ornament.
class EditorialDivider extends StatelessWidget {
  const EditorialDivider({
    super.key,
    this.verticalPadding = 16,
    this.horizontalPadding = 24,
  });

  final double verticalPadding;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.hairline.withValues(alpha: 0), p.hairline],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: 0.785398, // 45 deg
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  border: Border.all(color: p.ornament, width: 1.1),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.hairline, p.hairline.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
