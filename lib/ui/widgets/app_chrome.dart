import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppResponsive {
  const AppResponsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => width(context) < 600;

  static bool isTablet(BuildContext context) {
    final screenWidth = width(context);
    return screenWidth >= 600 && screenWidth < 1100;
  }

  static bool isDesktop(BuildContext context) => width(context) >= 1100;

  static bool useNavigationRail(BuildContext context) => width(context) >= 900;

  static bool isCompact(BuildContext context) => width(context) < 430;

  static bool isUltraCompact(BuildContext context) => width(context) < 380;

  static double maxContentWidth(BuildContext context, {bool wide = false}) {
    if (isDesktop(context)) {
      return wide ? 1280 : 1100;
    }
    if (isTablet(context)) {
      return wide ? 1040 : 900;
    }
    return double.infinity;
  }

  static double horizontalPadding(BuildContext context) {
    if (isUltraCompact(context)) return AppSpacing.sm;
    if (isCompact(context)) return AppSpacing.md;
    if (isTablet(context)) return AppSpacing.lg;
    if (isDesktop(context)) return AppSpacing.xl;
    return AppSpacing.md;
  }

  static double cardPadding(BuildContext context) {
    if (isUltraCompact(context)) return AppSpacing.sm;
    if (isCompact(context)) return AppSpacing.md;
    if (isTablet(context)) return AppSpacing.lg;
    if (isDesktop(context)) return AppSpacing.lg;
    return AppSpacing.md;
  }

  static double cardRadius(BuildContext context) {
    if (isUltraCompact(context)) return 20;
    if (isCompact(context)) return 22;
    if (isDesktop(context)) return 28;
    return 24;
  }

  static double sectionGap(BuildContext context) {
    if (isDesktop(context)) return AppSpacing.xl;
    if (isTablet(context)) return AppSpacing.lg;
    return AppSpacing.md;
  }

  static double bottomSafeInset(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  static EdgeInsets bottomActionBarPadding(
    BuildContext context, {
    double top = AppSpacing.sm,
    double bottom = AppSpacing.md,
  }) {
    final horizontal = horizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static double bottomActionBarReservedSpace(
    BuildContext context, {
    double actionHeight = 56,
    double top = AppSpacing.sm,
    double bottom = AppSpacing.md,
  }) {
    return actionHeight + top + bottom + bottomSafeInset(context);
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = AppSpacing.xs,
    double bottom = AppSpacing.xxl,
  }) {
    final horizontal = horizontalPadding(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

enum AppStatusTone { neutral, success, warning, error, info }

enum AppButtonVariant { primary, secondary, danger }

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: ClublineAppTheme.pageGradient),
      child: child,
    );
  }
}

class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth,
    this.wide = false,
  });

  final Widget child;
  final double? maxWidth;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              maxWidth ?? AppResponsive.maxContentWidth(context, wide: wide),
        ),
        child: child,
      ),
    );
  }
}

class AppAdaptiveColumns extends StatelessWidget {
  const AppAdaptiveColumns({
    super.key,
    required this.children,
    this.breakpoint = 920,
    this.gap = AppSpacing.md,
    this.flex = const [],
  });

  final List<Widget> children;
  final double breakpoint;
  final double gap;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint || children.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(height: gap),
                children[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              Expanded(
                flex: flex.length > index ? flex[index] : 1,
                child: children[index],
              ),
            ],
          ],
        );
      },
    );
  }
}

class AppResponsiveGrid extends StatelessWidget {
  const AppResponsiveGrid({
    super.key,
    required this.children,
    this.minChildWidth = 260,
    this.gap = AppSpacing.md,
  });

  final List<Widget> children;
  final double minChildWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (children.isEmpty) {
          return const SizedBox.shrink();
        }

        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppResponsive.maxContentWidth(context);
        final rawCount = ((maxWidth + gap) / (minChildWidth + gap)).floor();
        final columnCount = rawCount.clamp(1, 4);
        final itemWidth = columnCount == 1
            ? maxWidth
            : (maxWidth - ((columnCount - 1) * gap)) / columnCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.title,
    this.actions,
    this.appBar,
    required this.child,
    this.padding,
    this.wide = false,
    this.maxWidth,
    this.scrollable = true,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool wide;
  final double? maxWidth;
  final bool scrollable;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final resolvedAppBar =
        appBar ??
        (title == null ? null : AppBar(title: Text(title!), actions: actions));

    final content = AppContentFrame(
      maxWidth: maxWidth,
      wide: wide,
      child: scrollable
          ? SingleChildScrollView(
              padding:
                  padding ??
                  AppResponsive.pagePadding(
                    context,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xl,
                  ),
              child: child,
            )
          : Padding(
              padding:
                  padding ??
                  AppResponsive.pagePadding(
                    context,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xl,
                  ),
              child: child,
            ),
    );

    return Scaffold(
      appBar: resolvedAppBar,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          const AppPageBackground(child: SizedBox.expand()),
          SafeArea(maintainBottomViewPadding: true, child: content),
        ],
      ),
    );
  }
}

class AppBottomSafeAreaBar extends StatelessWidget {
  const AppBottomSafeAreaBar({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.maintainBottomViewPadding = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool maintainBottomViewPadding;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding ?? AppResponsive.bottomActionBarPadding(context);
    final resolvedBackground =
        backgroundColor ?? Theme.of(context).colorScheme.surface;

    return ColoredBox(
      color: resolvedBackground,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w900,
      height: 1.02,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: ClublineAppTheme.textMuted,
      height: 1.45,
    );

    final content = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ClublineAppTheme.goldSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: titleStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: subtitleStyle,
        ),
      ],
    );

    if (trailing == null || centered) {
      return content;
    }

    return AppAdaptiveColumns(
      breakpoint: 860,
      gap: AppSpacing.md,
      flex: const [3, 2],
      children: [
        content,
        Align(alignment: Alignment.topRight, child: trailing!),
      ],
    );
  }
}

class AppHeroPanel extends StatelessWidget {
  const AppHeroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.media,
    this.trailing,
    this.badges = const [],
    this.actions = const [],
    this.footer,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? media;
  final Widget? trailing;
  final List<Widget> badges;
  final List<Widget> actions;
  final Widget? footer;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final horizontalAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    Widget buildContent() {
      return Column(
        crossAxisAlignment: horizontalAlignment,
        children: [
          if (media != null &&
              (trailing == null || !AppResponsive.isDesktop(context))) ...[
            Center(child: media!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              textAlign: textAlign,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ClublineAppTheme.goldSoft,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            title,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.04,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: ClublineAppTheme.textMuted,
              height: 1.48,
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: centered ? WrapAlignment.center : WrapAlignment.start,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: badges,
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: centered ? WrapAlignment.center : WrapAlignment.start,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
        ],
      );
    }

    final padding = EdgeInsets.all(
      AppResponsive.isDesktop(context)
          ? AppSpacing.xl
          : AppResponsive.cardPadding(context),
    );

    return Container(
      width: double.infinity,
      decoration: ClublineAppTheme.heroDecoration(
        radius: AppResponsive.isCompact(context) ? 24 : 30,
      ),
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useSplitLayout =
                trailing != null && constraints.maxWidth >= 980;

            if (!useSplitLayout) {
              return buildContent();
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: buildContent()),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: constraints.maxWidth * 0.34, child: trailing!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final accentColor = emphasized
        ? ClublineAppTheme.goldSoft
        : ClublineAppTheme.infoSoft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ClublineAppTheme.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emphasized
              ? ClublineAppTheme.outlineStrong
              : ClublineAppTheme.outlineSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            backgroundColor: accentColor.withValues(alpha: 0.16),
            iconColor: accentColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ClublineAppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ClublineAppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppDetailItem {
  const AppDetailItem({
    required this.label,
    required this.value,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool emphasized;
}

class AppDetailsList extends StatelessWidget {
  const AppDetailsList({super.key, required this.items});

  final List<AppDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0)
            Divider(height: AppSpacing.md, color: ClublineAppTheme.outlineSoft),
          _AppDetailRow(item: items[index]),
        ],
      ],
    );
  }
}

class _AppDetailRow extends StatelessWidget {
  const _AppDetailRow({required this.item});

  final AppDetailItem item;

  @override
  Widget build(BuildContext context) {
    final valueColor = item.emphasized
        ? ClublineAppTheme.goldSoft
        : ClublineAppTheme.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              item.icon,
              size: 16,
              color: item.emphasized
                  ? ClublineAppTheme.goldSoft
                  : ClublineAppTheme.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: ClublineAppTheme.textMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            item.value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || subtitle != null || trailing != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    AppIconBadge(icon: icon!),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: ClublineAppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AppFeatureCard extends StatelessWidget {
  const AppFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.badge,
    this.actionLabel,
    this.actionIcon,
    this.onTap,
    this.onAction,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? badge;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = emphasized
        ? ClublineAppTheme.surfaceRaised
        : Theme.of(context).cardColor;

    return Card(
      color: surfaceColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onAction,
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(
                    icon: icon,
                    backgroundColor: emphasized
                        ? ClublineAppTheme.gold.withValues(alpha: 0.18)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: ClublineAppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    badge!,
                  ],
                ],
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppActionButton(
                  label: actionLabel!,
                  icon: actionIcon ?? Icons.arrow_forward_outlined,
                  variant: emphasized
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  expand: AppResponsive.isCompact(context),
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.tone = AppStatusTone.info,
  });

  final String message;
  final IconData icon;
  final AppStatusTone tone;

  Color _toneColor() {
    switch (tone) {
      case AppStatusTone.success:
        return ClublineAppTheme.success;
      case AppStatusTone.warning:
        return ClublineAppTheme.warning;
      case AppStatusTone.error:
        return ClublineAppTheme.danger;
      case AppStatusTone.info:
        return ClublineAppTheme.infoSoft;
      case AppStatusTone.neutral:
        return ClublineAppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: toneColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: toneColor, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
    final compact = AppResponsive.isCompact(context);

    return AppSurfaceCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            AppIconBadge(
              icon: icon,
              size: compact ? 52 : 60,
              borderRadius: 999,
            ),
            if (eyebrow != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                eyebrow!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ClublineAppTheme.goldSoft,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppActionButton(
                label: actionLoading ? 'Attivazione...' : actionLabel!,
                icon: actionLoading
                    ? null
                    : (actionIcon ?? Icons.arrow_forward_outlined),
                isLoading: actionLoading,
                variant: AppButtonVariant.secondary,
                expand: compact,
                onPressed: actionLoading ? null : onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label = 'Caricamento in corso...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClublineAppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppStatusCard(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppStatusCard(
      icon: Icons.error_outline,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: Icons.refresh_outlined,
      onAction: onAction,
    );
  }
}

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: variant == AppButtonVariant.primary
            ? ClublineAppTheme.onAccent
            : ClublineAppTheme.goldSoft,
      ),
    );
    final child = isLoading
        ? spinner
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(label)),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.danger:
        button = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
    }

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
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
        color: backgroundColor ?? ClublineAppTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(
        icon,
        size: compact ? iconSize - 1 : iconSize,
        color: iconColor ?? ClublineAppTheme.goldSoft,
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
  });

  final String label;
  final AppStatusTone tone;

  Color _foreground() {
    switch (tone) {
      case AppStatusTone.success:
        return ClublineAppTheme.successSoft;
      case AppStatusTone.warning:
        return ClublineAppTheme.warningSoft;
      case AppStatusTone.error:
        return ClublineAppTheme.dangerSoft;
      case AppStatusTone.info:
        return ClublineAppTheme.infoSoft;
      case AppStatusTone.neutral:
        return ClublineAppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foreground();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
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
    final tone =
        color ??
        (emphasized ? ClublineAppTheme.goldSoft : ClublineAppTheme.textPrimary);
    final backgroundColor = color == null
        ? (emphasized
              ? ClublineAppTheme.gold.withValues(alpha: 0.14)
              : ClublineAppTheme.surfaceAlt)
        : color!.withValues(alpha: 0.14);
    final borderColor = color == null
        ? (emphasized
              ? ClublineAppTheme.outlineStrong
              : ClublineAppTheme.outlineSoft)
        : color!.withValues(alpha: 0.35);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm,
        vertical: compact ? AppSpacing.xxs + 2 : AppSpacing.xs,
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
            const SizedBox(width: AppSpacing.xs),
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
              const SizedBox(width: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.xs),
            AppCountPill(label: '$count', emphasized: true),
          ],
        ],
      );
    }

    return Row(
      children: [
        AppIconBadge(icon: icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              letterSpacing: 0.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showCount) AppCountPill(label: '$count', emphasized: true),
      ],
    );
  }
}
