import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class ClublineBrandLogo extends StatelessWidget {
  const ClublineBrandLogo({
    super.key,
    this.width = 220,
    this.radius = 28,
    this.showFrame = false,
  });

  final double width;
  final double radius;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/clubline_generic_logo.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Clubline',
    );

    if (!showFrame) {
      return logo;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: UltrasAppTheme.outlineStrong.withValues(alpha: 0.78),
        ),
        boxShadow: UltrasAppTheme.softShadow,
      ),
      child: logo,
    );
  }
}
