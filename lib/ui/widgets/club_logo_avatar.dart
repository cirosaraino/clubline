import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_theme.dart';
import '../../core/club_logo_resolver.dart';

class ClubLogoAvatar extends StatelessWidget {
  const ClubLogoAvatar({
    super.key,
    required this.logoUrl,
    this.logoStoragePath,
    required this.size,
    required this.fallbackIcon,
    this.borderWidth = 2,
  });

  final String? logoUrl;
  final String? logoStoragePath;
  final double size;
  final IconData fallbackIcon;
  final double borderWidth;

  bool get _hasAnyLogoReference {
    return (logoUrl ?? '').trim().isNotEmpty ||
        (logoStoragePath ?? '').trim().isNotEmpty;
  }

  bool _isSvgLogo(String resolvedUrl) {
    final normalized = resolvedUrl.trim().toLowerCase();
    return normalized.endsWith('.svg') ||
        normalized.contains('image/svg+xml') ||
        normalized.contains('format=svg');
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLogoFuture = ClubLogoResolver.instance.resolveUrl(
      storagePath: logoStoragePath,
      fallbackUrl: logoUrl,
    );

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.82),
        border: Border.all(
          color: ClublineAppTheme.outlineStrong,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: !_hasAnyLogoReference
                ? _ClubFallbackLogo(size: size, icon: fallbackIcon)
                : FutureBuilder<String?>(
                    future: resolvedLogoFuture,
                    builder: (context, snapshot) {
                      final resolvedUrl = snapshot.data?.trim();
                      if (resolvedUrl == null || resolvedUrl.isEmpty) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _ClubFallbackLogo(
                          size: size,
                          icon: fallbackIcon,
                        );
                      }

                      if (_isSvgLogo(resolvedUrl)) {
                        return SvgPicture.network(
                          resolvedUrl,
                          fit: BoxFit.contain,
                          placeholderBuilder: (_) =>
                              _ClubFallbackLogo(size: size, icon: fallbackIcon),
                        );
                      }

                      return Image.network(
                        resolvedUrl,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) =>
                            _ClubFallbackLogo(size: size, icon: fallbackIcon),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClubFallbackLogo extends StatelessWidget {
  const _ClubFallbackLogo({required this.size, required this.icon});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.42, color: ClublineAppTheme.goldSoft),
    );
  }
}
