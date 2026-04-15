import 'package:flutter/material.dart';

import '../../core/lineup_pitch_layouts.dart';
import '../../models/player_profile.dart';

class LineupPitchView extends StatelessWidget {
  const LineupPitchView({
    super.key,
    required this.formationModule,
    required this.selectedPlayersByPosition,
    required this.onTapPosition,
    required this.enabled,
  });

  final String formationModule;
  final Map<String, PlayerProfile?> selectedPlayersByPosition;
  final ValueChanged<String> onTapPosition;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final rows = lineupPitchRowsFor(formationModule);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        final isPhone = maxWidth < 600;
        final isSmallPhone = maxWidth < 380;
        final isVerySmallPhone = maxWidth < 340;
        final isTightHeight = maxHeight < 520;
        final isVeryTightHeight = maxHeight < 440;

        final goalkeeperWidth = isVerySmallPhone
            ? (maxWidth * 0.23).clamp(52.0, 72.0).toDouble()
            : isSmallPhone
                ? (maxWidth * 0.24).clamp(56.0, 78.0).toDouble()
                : (maxWidth * 0.24).clamp(62.0, 88.0).toDouble();

        final goalkeeperHeight = isVeryTightHeight
            ? (maxHeight * 0.12).clamp(38.0, 52.0).toDouble()
            : isTightHeight
                ? (maxHeight * 0.13).clamp(42.0, 58.0).toDouble()
                : (maxHeight * 0.14).clamp(48.0, 68.0).toDouble();

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isPhone ? 20 : 24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8FD18F),
                Color(0xFF6FBC70),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PitchPainter(
                    compact: isPhone,
                    ultraCompact: isSmallPhone || isTightHeight,
                  ),
                ),
              ),
              ..._buildOutfieldRows(
                context,
                constraints,
                rows,
              ),
              _buildGoalkeeper(
                constraints,
                goalkeeperWidth,
                goalkeeperHeight,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildOutfieldRows(
    BuildContext context,
    BoxConstraints constraints,
    List<List<String>> rows,
  ) {
    final rowTopFractions = _rowTopFractions(
      rowCount: rows.length,
      maxWidth: constraints.maxWidth,
      maxHeight: constraints.maxHeight,
    );

    final widgets = <Widget>[];

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final topFraction = rowTopFractions[rowIndex];

      final rowGap = _horizontalGap(
        itemCount: row.length,
        totalWidth: constraints.maxWidth,
      );

      final rowSpotWidth = _spotWidthForRow(
        totalWidth: constraints.maxWidth,
        totalHeight: constraints.maxHeight,
        itemCount: row.length,
        gap: rowGap,
      );

      final rowSpotHeight = _spotHeightForWidth(
        spotWidth: rowSpotWidth,
        maxHeight: constraints.maxHeight,
      );

      final totalRowWidth =
          (rowSpotWidth * row.length) + (rowGap * (row.length - 1));
      final startLeft = (constraints.maxWidth - totalRowWidth) / 2;

      final horizontalEdgePadding = constraints.maxWidth < 360 ? 6.0 : 8.0;
      final minLeft = horizontalEdgePadding;
      final maxLeft = constraints.maxWidth - rowSpotWidth - horizontalEdgePadding;

      final minSpacing = _minimumHorizontalSeparation(
        rowSize: row.length,
        spotWidth: rowSpotWidth,
        totalWidth: constraints.maxWidth,
      );

      final desiredLefts = _desiredLeftsForRow(
        row: row,
        constraints: constraints,
        rowSpotWidth: rowSpotWidth,
        rowGap: rowGap,
        startLeft: startLeft,
      );

      final resolvedLefts = _resolveRowLefts(
        desiredLefts: desiredLefts,
        spotWidth: rowSpotWidth,
        minLeft: minLeft,
        maxLeft: maxLeft,
        minSpacing: minSpacing,
      );

      for (var index = 0; index < row.length; index++) {
        final positionCode = row[index];
        final baseTop =
            (constraints.maxHeight * topFraction) - (rowSpotHeight / 2);

        final verticalOffset = _verticalOffsetForPositionCode(
          positionCode,
          rowSpotHeight,
          constraints.maxHeight,
        );

        final top = (baseTop + verticalOffset)
            .clamp(4.0, constraints.maxHeight - rowSpotHeight - 4.0)
            .toDouble();

        widgets.add(
          Positioned(
            left: resolvedLefts[index],
            top: top,
            width: rowSpotWidth,
            height: rowSpotHeight,
            child: _PitchSpot(
              positionCode: positionCode,
              player: selectedPlayersByPosition[positionCode],
              enabled: enabled,
              onTap: () => onTapPosition(positionCode),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<double> _desiredLeftsForRow({
    required List<String> row,
    required BoxConstraints constraints,
    required double rowSpotWidth,
    required double rowGap,
    required double startLeft,
  }) {
    if (row.isEmpty) {
      return const <double>[];
    }

    final rowSpan = _targetRowSpan(
      row: row,
      maxWidth: constraints.maxWidth,
      spotWidth: rowSpotWidth,
    );

    final centerX = constraints.maxWidth / 2;

    final sidePadding = constraints.maxWidth < 360 ? 6.0 : 8.0;

    final usableLeft =
        (centerX - (rowSpan / 2)).clamp(sidePadding, constraints.maxWidth).toDouble();

    final usableRight = (centerX + (rowSpan / 2))
        .clamp(0.0, constraints.maxWidth - sidePadding)
        .toDouble();

    final slotCenters = _distributedCenters(
      count: row.length,
      minCenter: usableLeft + (rowSpotWidth / 2),
      maxCenter: usableRight - (rowSpotWidth / 2),
    );

    return List<double>.generate(row.length, (index) {
      final positionCode = row[index];
      final baseLeft = slotCenters[index] - (rowSpotWidth / 2);

      final horizontalOffset = _horizontalOffsetForRowPosition(
        row: row,
        positionCode: positionCode,
        spotWidth: rowSpotWidth,
        maxWidth: constraints.maxWidth,
      );

      return baseLeft + horizontalOffset;
    });
  }

  double _targetRowSpan({
    required List<String> row,
    required double maxWidth,
    required double spotWidth,
  }) {
    final count = row.length;
    final horizontalPadding = maxWidth < 360 ? 12.0 : 16.0 * 2;
    final maxUsableSpan = maxWidth - horizontalPadding;

    if (count == 1) {
      return spotWidth;
    }

    final isOnlyWidePair =
        count == 2 && row.contains('ES') && row.contains('ED');

    if (isOnlyWidePair) {
      final factor = maxWidth < 360 ? 0.60 : 0.50;
      return (maxWidth * factor).clamp(
        spotWidth * 2.1,
        maxUsableSpan,
      ).toDouble();
    }

    final wideRoles = {'TS', 'TD', 'ES', 'ED', 'AS', 'AD'};
    final hasWideRoles = row.any(wideRoles.contains);

    final isSmallPhone = maxWidth < 380;

    final baseSpacingMultiplier = switch (count) {
      2 => hasWideRoles
          ? (isSmallPhone ? 1.20 : 1.45)
          : (isSmallPhone ? 1.00 : 1.20),
      3 => hasWideRoles
          ? (isSmallPhone ? 0.95 : 1.12)
          : (isSmallPhone ? 0.88 : 1.00),
      4 => isSmallPhone ? 0.78 : 0.94,
      5 => isSmallPhone ? 0.60 : 0.84,
      _ => isSmallPhone ? 0.56 : 0.78,
    };

    final span =
        (spotWidth * count) + (spotWidth * (count - 1) * baseSpacingMultiplier);

    return span.clamp(
      spotWidth * count,
      maxUsableSpan,
    ).toDouble();
  }

  List<double> _distributedCenters({
    required int count,
    required double minCenter,
    required double maxCenter,
  }) {
    if (count <= 0) {
      return const <double>[];
    }

    if (count == 1) {
      return <double>[(minCenter + maxCenter) / 2];
    }

    final step = (maxCenter - minCenter) / (count - 1);

    return List<double>.generate(
      count,
      (index) => minCenter + (step * index),
    );
  }

  double _horizontalOffsetForRowPosition({
    required List<String> row,
    required String positionCode,
    required double spotWidth,
    required double maxWidth,
  }) {
    final isOnlyWidePair =
        row.length == 2 && row.contains('ES') && row.contains('ED');

    if (isOnlyWidePair) {
      final factor = maxWidth < 360 ? 0.04 : 0.08;
      switch (positionCode) {
        case 'ES':
          return -(spotWidth * factor);
        case 'ED':
          return spotWidth * factor;
        default:
          return 0;
      }
    }

    return _horizontalOffsetForPositionCode(
      positionCode,
      spotWidth,
      maxWidth,
    );
  }

  double _horizontalOffsetForPositionCode(
    String positionCode,
    double spotWidth,
    double maxWidth,
  ) {
    final tightFactor = maxWidth < 360 ? 0.70 : 1.0;

    switch (positionCode) {
      case 'TS':
        return -(spotWidth * 0.24 * tightFactor);
      case 'TD':
        return spotWidth * 0.24 * tightFactor;
      case 'ES':
        return -(spotWidth * 0.20 * tightFactor);
      case 'ED':
        return spotWidth * 0.20 * tightFactor;
      case 'AS':
        return -(spotWidth * 0.18 * tightFactor);
      case 'AD':
        return spotWidth * 0.18 * tightFactor;
      case 'CCS':
        return -(spotWidth * 0.10 * tightFactor);
      case 'CCD':
        return spotWidth * 0.10 * tightFactor;
      case 'CDCS':
        return -(spotWidth * 0.12 * tightFactor);
      case 'CDCD':
        return spotWidth * 0.12 * tightFactor;
      default:
        return 0;
    }
  }

  double _verticalOffsetForPositionCode(
    String positionCode,
    double spotHeight,
    double maxHeight,
  ) {
    final factor = maxHeight < 460 ? 0.72 : 1.0;

    if (positionCode == 'COC' ||
        positionCode == 'COCS' ||
        positionCode == 'COCD') {
      return -(spotHeight * 0.14 * factor);
    }

    if (positionCode == 'CDCS' || positionCode == 'CDCD') {
      return spotHeight * 0.14 * factor;
    }

    if (positionCode == 'CCS' || positionCode == 'CCD') {
      return spotHeight * 0.05 * factor;
    }

    if (positionCode == 'CDC') {
      return spotHeight * 0.10 * factor;
    }

    return 0;
  }

  double _minimumHorizontalSeparation({
    required int rowSize,
    required double spotWidth,
    required double totalWidth,
  }) {
    final isSmallPhone = totalWidth < 380;

    return switch (rowSize) {
      2 => spotWidth * (isSmallPhone ? 0.18 : 0.26),
      3 => spotWidth * (isSmallPhone ? 0.12 : 0.17),
      4 => spotWidth * (isSmallPhone ? 0.06 : 0.10),
      5 => spotWidth * (isSmallPhone ? 0.03 : 0.06),
      _ => spotWidth * (isSmallPhone ? 0.04 : 0.08),
    };
  }

  List<double> _resolveRowLefts({
    required List<double> desiredLefts,
    required double spotWidth,
    required double minLeft,
    required double maxLeft,
    required double minSpacing,
  }) {
    if (desiredLefts.isEmpty) {
      return const <double>[];
    }

    final indexed = desiredLefts.asMap().entries.map((entry) {
      return (index: entry.key, left: entry.value);
    }).toList();

    indexed.sort((a, b) => a.left.compareTo(b.left));

    final count = indexed.length;
    final sortedLefts = indexed.map((e) => e.left).toList();

    final totalRequiredWidth =
        (count * spotWidth) + ((count - 1) * minSpacing);
    final availableWidth = (maxLeft - minLeft) + spotWidth;

    if (totalRequiredWidth > availableWidth && count > 1) {
      final compressedSpacing =
          ((availableWidth - (count * spotWidth)) / (count - 1))
              .clamp(0.0, minSpacing)
              .toDouble();

      final compressed = List<double>.generate(
        count,
        (index) => minLeft + index * (spotWidth + compressedSpacing),
      );

      final backToOriginalOrder = List<double>.filled(count, 0);
      for (var i = 0; i < count; i++) {
        backToOriginalOrder[indexed[i].index] = compressed[i];
      }
      return backToOriginalOrder;
    }

    for (var i = 0; i < count; i++) {
      sortedLefts[i] = sortedLefts[i].clamp(minLeft, maxLeft).toDouble();
    }

    for (var i = 1; i < count; i++) {
      final minAllowed = sortedLefts[i - 1] + spotWidth + minSpacing;
      if (sortedLefts[i] < minAllowed) {
        sortedLefts[i] = minAllowed;
      }
    }

    if (sortedLefts.last > maxLeft) {
      final overflow = sortedLefts.last - maxLeft;
      for (var i = 0; i < count; i++) {
        sortedLefts[i] -= overflow;
      }
    }

    if (sortedLefts.first < minLeft) {
      final underflow = minLeft - sortedLefts.first;
      for (var i = 0; i < count; i++) {
        sortedLefts[i] += underflow;
      }
    }

    for (var i = count - 2; i >= 0; i--) {
      final maxAllowed = sortedLefts[i + 1] - spotWidth - minSpacing;
      if (sortedLefts[i] > maxAllowed) {
        sortedLefts[i] = maxAllowed;
      }
    }

    for (var i = 0; i < count; i++) {
      sortedLefts[i] = sortedLefts[i].clamp(minLeft, maxLeft).toDouble();
    }

    final backToOriginalOrder = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      backToOriginalOrder[indexed[i].index] = sortedLefts[i];
    }

    return backToOriginalOrder;
  }

  Widget _buildGoalkeeper(
    BoxConstraints constraints,
    double spotWidth,
    double spotHeight,
  ) {
    final maxHeight = constraints.maxHeight;
    final keeperTopFactor = maxHeight < 440
        ? 0.82
        : maxHeight < 520
            ? 0.84
            : 0.85;

    return Positioned(
      left: (constraints.maxWidth * 0.5) - (spotWidth / 2),
      top: (constraints.maxHeight * keeperTopFactor) - (spotHeight / 2),
      width: spotWidth,
      height: spotHeight,
      child: _PitchSpot(
        positionCode: 'POR',
        player: selectedPlayersByPosition['POR'],
        enabled: enabled,
        onTap: () => onTapPosition('POR'),
      ),
    );
  }

  List<double> _rowTopFractions({
    required int rowCount,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (rowCount <= 0) return const [];
    if (rowCount == 1) {
      if (maxHeight < 460) return const [0.44];
      return const [0.46];
    }

    final isSmallPhone = maxWidth < 380;
    final isTightHeight = maxHeight < 520;
    final isVeryTightHeight = maxHeight < 440;

    final double start;
    final double end;

    if (isVeryTightHeight) {
      start = 0.66;
      end = 0.18;
    } else if (isTightHeight) {
      start = 0.67;
      end = 0.17;
    } else if (isSmallPhone) {
      start = 0.68;
      end = 0.16;
    } else {
      start = 0.69;
      end = 0.15;
    }

    return List<double>.generate(
      rowCount,
      (index) => start - ((start - end) * index / (rowCount - 1)),
    );
  }

  double _horizontalGap({
    required int itemCount,
    required double totalWidth,
  }) {
    final isSmallPhone = totalWidth < 380;

    if (isSmallPhone) {
      return switch (itemCount) {
        5 => 3,
        4 => 4,
        3 => 6,
        _ => 8,
      };
    }

    return switch (itemCount) {
      5 => 6,
      4 => 8,
      _ => 10,
    };
  }

  double _spotWidthForRow({
    required double totalWidth,
    required double totalHeight,
    required int itemCount,
    required double gap,
  }) {
    final isSmallPhone = totalWidth < 380;
    final isVerySmallPhone = totalWidth < 340;
    final isTightHeight = totalHeight < 500;

    final sidePadding = isVerySmallPhone
        ? 10.0
        : isSmallPhone
            ? 12.0
            : 18.0;

    final availableWidth =
        totalWidth - (sidePadding * 2) - (gap * (itemCount - 1));

    final densityFactor = isVerySmallPhone
        ? 0.90
        : isSmallPhone
            ? 0.92
            : 0.96;

    final calculatedWidth = (availableWidth / itemCount) * densityFactor;

    final minWidth = isVerySmallPhone
        ? 40.0
        : isSmallPhone
            ? 44.0
            : 50.0;

    final maxWidth = isTightHeight
        ? 74.0
        : isSmallPhone
            ? 80.0
            : 88.0;

    return calculatedWidth.clamp(minWidth, maxWidth).toDouble();
  }

  double _spotHeightForWidth({
    required double spotWidth,
    required double maxHeight,
  }) {
    final isTightHeight = maxHeight < 520;
    final isVeryTightHeight = maxHeight < 440;

    final calculatedHeight = spotWidth * (isVeryTightHeight ? 0.70 : 0.76);

    final minHeight = isVeryTightHeight
        ? 34.0
        : isTightHeight
            ? 38.0
            : 44.0;

    final heightCap = (maxHeight * (isVeryTightHeight ? 0.105 : 0.125))
        .clamp(
          isVeryTightHeight ? 40.0 : 44.0,
          isVeryTightHeight ? 50.0 : 66.0,
        )
        .toDouble();

    return calculatedHeight.clamp(minHeight, heightCap).toDouble();
  }
}

class _PitchSpot extends StatelessWidget {
  const _PitchSpot({
    required this.positionCode,
    required this.player,
    required this.enabled,
    required this.onTap,
  });

  final String positionCode;
  final PlayerProfile? player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPlayer = player != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: hasPlayer
          ? colorScheme.surface.withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final ultraCompact = width < 54 || height < 40;
            final veryCompact = width < 62 || height < 46;
            final compact = width < 72 || height < 56;
            final showFullName = hasPlayer && width >= 78 && height >= 62;
            final showPositionBadge = !ultraCompact;

            final primaryLabel = hasPlayer ? player!.idConsoleDisplay : 'Scegli';

            final displayedLabel = hasPlayer
                ? _mobileFriendlyPrimaryLabel(
                    player!.idConsoleDisplay,
                    ultraCompact: ultraCompact,
                    veryCompact: veryCompact,
                  )
                : (ultraCompact ? '+' : 'Scegli');

            final horizontalPadding = ultraCompact
                ? 3.0
                : veryCompact
                    ? 4.0
                    : compact
                        ? 5.0
                        : 7.0;

            final verticalPadding = ultraCompact
                ? 2.0
                : veryCompact
                    ? 3.0
                    : compact
                        ? 4.0
                        : 6.0;

            final badgeFontSize = ultraCompact
                ? 7.5
                : veryCompact
                    ? 8.0
                    : compact
                        ? 9.0
                        : 10.5;

            final primaryFontSize = ultraCompact
                ? 8.0
                : veryCompact
                    ? 9.0
                    : compact
                        ? 10.0
                        : 11.5;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showPositionBadge)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ultraCompact ? 3 : 5,
                          vertical: ultraCompact ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          positionCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: badgeFontSize,
                                height: 1.0,
                              ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: showPositionBadge
                        ? (ultraCompact ? 1 : compact ? 2 : 4)
                        : 0,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        displayedLabel,
                        maxLines: ultraCompact ? 1 : 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight:
                                  hasPlayer ? FontWeight.w600 : FontWeight.w400,
                              fontSize: primaryFontSize,
                              height: 1.0,
                            ),
                      ),
                    ),
                  ),
                  if (showFullName)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        player!.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 8,
                              height: 1.0,
                            ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _mobileFriendlyPrimaryLabel(
    String value, {
    required bool ultraCompact,
    required bool veryCompact,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '+';

    if (ultraCompact) {
      return trimmed.length > 6 ? trimmed.substring(0, 6) : trimmed;
    }

    if (veryCompact) {
      return trimmed.length > 10 ? trimmed.substring(0, 10) : trimmed;
    }

    return trimmed;
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter({
    required this.compact,
    required this.ultraCompact,
  });

  final bool compact;
  final bool ultraCompact;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = ultraCompact ? 1.2 : compact ? 1.6 : 2.0;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final cornerRadius = ultraCompact ? 20.0 : compact ? 22.0 : 24.0;

    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius),
    );

    canvas.drawRRect(outer, fillPaint);
    canvas.drawRRect(outer, linePaint);

    final halfY = size.height / 2;
    canvas.drawLine(Offset(0, halfY), Offset(size.width, halfY), linePaint);

    final circleRadius = (size.width * (ultraCompact ? 0.10 : 0.12))
        .clamp(18.0, 44.0)
        .toDouble();

    final center = Offset(size.width / 2, halfY);
    canvas.drawCircle(center, circleRadius, linePaint);
    canvas.drawCircle(
      center,
      ultraCompact ? 2 : 3,
      Paint()..color = Colors.white,
    );

    final topBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.12),
      width: size.width * (ultraCompact ? 0.42 : 0.46),
      height: size.height * (ultraCompact ? 0.12 : 0.14),
    );

    final bottomBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.88),
      width: size.width * (ultraCompact ? 0.42 : 0.46),
      height: size.height * (ultraCompact ? 0.12 : 0.14),
    );

    canvas.drawRect(topBox, linePaint);
    canvas.drawRect(bottomBox, linePaint);

    final topSmallBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.06),
      width: size.width * (ultraCompact ? 0.18 : 0.22),
      height: size.height * (ultraCompact ? 0.05 : 0.07),
    );

    final bottomSmallBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.94),
      width: size.width * (ultraCompact ? 0.18 : 0.22),
      height: size.height * (ultraCompact ? 0.05 : 0.07),
    );

    canvas.drawRect(topSmallBox, linePaint);
    canvas.drawRect(bottomSmallBox, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.ultraCompact != ultraCompact;
  }
}