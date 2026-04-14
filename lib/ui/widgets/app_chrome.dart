import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AppResponsive {
  const AppResponsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => width(context) < 600;

  static bool isCompact(BuildContext context) => width(context) < 430;

  static bool isUltraCompact(BuildContext context) => width(context) < 380;

  static double horizontalPadding(BuildContext context) {
    if (isUltraCompact(context)) return 12;
    if (isCompact(context)) return 14;
    return 16;
  }

  static double cardPadding(BuildContext context) {
    if (isUltraCompact(context)) return 14;
    if (isCompact(context)) return 16;
    return 18;
  }

  static double cardRadius(BuildContext context) {
    if (isUltraCompact(context)) return 20;
    if (isCompact(context)) return 22;
    return 24;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 12,
    double bottom = 96,
  }) {
    final horizontal = horizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: UltrasAppTheme.pageGradient,
      ),
      child: child,
    );
  }
}

class AppStatusCard extends StatelessWidget {
  const AppStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.eyebrow,
    this.actionLabel,
    this.actionIcon,
    this.actionLoading = false,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? eyebrow;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool actionLoading;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final padding = AppResponsive.cardPadding(context);
    final compact = AppResponsive.isCompact(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(padding + (compact ? 0 : 6)),
        child: Column(
          children: [
            AppIconBadge(
              icon: icon,
              size: compact ? 58 : 68,
              borderRadius: 999,
            ),
            if (eyebrow != null) ...[
              const SizedBox(height: 16),
              Text(
                eyebrow!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: UltrasAppTheme.goldSoft,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UltrasAppTheme.textMuted,
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: compact ? double.infinity : null,
                child: OutlinedButton.icon(
                  onPressed: actionLoading ? null : onAction,
                  icon: actionLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(actionIcon ?? Icons.arrow_forward_outlined),
                  label: Text(actionLoading ? 'Attivazione...' : actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.size = 46,
    this.iconSize = 20,
    this.borderRadius = 16,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double borderRadius;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    return Container(
      width: compact ? size - 4 : size,
      height: compact ? size - 4 : size,
      decoration: BoxDecoration(
        color: backgroundColor ?? UltrasAppTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(
        icon,
        size: compact ? iconSize - 1 : iconSize,
        color: iconColor ?? UltrasAppTheme.goldSoft,
      ),
    );
  }
}

class AppCountPill extends StatelessWidget {
  const AppCountPill({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isUltraCompact(context);
    final tone = color ?? (emphasized ? UltrasAppTheme.goldSoft : UltrasAppTheme.textPrimary);
    final backgroundColor = color == null
        ? (emphasized
              ? UltrasAppTheme.gold.withValues(alpha: 0.14)
              : UltrasAppTheme.surfaceAlt)
        : color!.withValues(alpha: 0.14);
    final borderColor = color == null
        ? (emphasized ? UltrasAppTheme.outlineStrong : UltrasAppTheme.outlineSoft)
        : color!.withValues(alpha: 0.35);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: tone),
            const SizedBox(width: 8),
          ],
          Text(
            value == null ? label : '$label $value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 11 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.showCount = true,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final compact = AppResponsive.isCompact(context);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (showCount) ...[
            const SizedBox(height: 10),
            AppCountPill(
              label: '$count',
              emphasized: true,
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        AppIconBadge(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (showCount)
          AppCountPill(
            label: '$count',
            emphasized: true,
          ),
      ],
    );
  }
}
