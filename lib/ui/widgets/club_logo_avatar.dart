import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_theme.dart';

class ClubLogoAvatar extends StatelessWidget {
  const ClubLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.size,
    required this.fallbackIcon,
    this.borderWidth = 2,
  });

  final String? logoUrl;
  final double size;
  final IconData fallbackIcon;
  final double borderWidth;

  bool get _hasLogoUrl => (logoUrl ?? '').trim().isNotEmpty;

  bool get _isSvgLogo {
    final normalized = logoUrl?.trim().toLowerCase() ?? '';
    return normalized.endsWith('.svg') ||
        normalized.contains('image/svg+xml') ||
        normalized.contains('format=svg');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: UltrasAppTheme.surfaceAlt.withValues(alpha: 0.82),
        border: Border.all(color: UltrasAppTheme.outlineStrong, width: borderWidth),
      ),
      child: ClipOval(
        child: !_hasLogoUrl
            ? _ClubFallbackLogo(size: size, icon: fallbackIcon)
            : _isSvgLogo
                ? SvgPicture.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    placeholderBuilder: (_) =>
                        _ClubFallbackLogo(size: size, icon: fallbackIcon),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _ClubFallbackLogo(size: size, icon: fallbackIcon),
                  ),
      ),
    );
  }
}

class _ClubFallbackLogo extends StatelessWidget {
  const _ClubFallbackLogo({
    required this.size,
    required this.icon,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UltrasAppTheme.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.42, color: UltrasAppTheme.goldSoft),
    );
  }
}
