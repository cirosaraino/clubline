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
        final goalkeeperWidth =
            (constraints.maxWidth * 0.24).clamp(70.0, 90.0).toDouble();
        final goalkeeperHeight =
            (constraints.maxHeight * 0.14).clamp(54.0, 72.0).toDouble();

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
                  painter: _PitchPainter(),
                ),
              ),
              ..._buildOutfieldRows(
                context,
                constraints,
                rows,
                goalkeeperHeight,
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
    double goalkeeperHeight,
  ) {
    if (rows.isEmpty) {
      return const <Widget>[];
    }

    final rowTopFractions = _rowTopFractions(rows.length);
    final widgets = <Widget>[];

    final rowLayouts = <_RowLayoutData>[];

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final topFraction = rowTopFractions[rowIndex];

      final rowGap = _horizontalGap(row.length);
      final rowSpotWidth = _spotWidthForRow(
        constraints.maxWidth,
        row.length,
        rowGap,
      );
      final rowSpotHeight = _spotHeightForWidth(
        rowSpotWidth,
        constraints.maxHeight,
      );

      final totalRowWidth =
          (rowSpotWidth * row.length) + (rowGap * (row.length - 1));
      final startLeft = (constraints.maxWidth - totalRowWidth) / 2;

      final minLeft = 8.0;
      final maxLeft = constraints.maxWidth - rowSpotWidth - 8.0;
      final minSpacing = _minimumHorizontalSeparation(row.length, rowSpotWidth);

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

      final desiredCenterY = constraints.maxHeight * topFraction;
      final desiredTop = desiredCenterY - (rowSpotHeight / 2);

      final minOffset = _minimumVerticalOffsetForRow(row, rowSpotHeight);
      final maxOffset = _maximumVerticalOffsetForRow(row, rowSpotHeight);

      rowLayouts.add(
        _RowLayoutData(
          row: row,
          lefts: resolvedLefts,
          spotWidth: rowSpotWidth,
          spotHeight: rowSpotHeight,
          desiredTop: desiredTop,
          minOffset: minOffset,
          maxOffset: maxOffset,
        ),
      );
    }

    final resolvedTops = _resolveRowTops(
      rows: rowLayouts,
      maxHeight: constraints.maxHeight,
      goalkeeperHeight: goalkeeperHeight,
    );

    for (var rowIndex = 0; rowIndex < rowLayouts.length; rowIndex++) {
      final layout = rowLayouts[rowIndex];
      final rowTop = resolvedTops[rowIndex];

      for (var index = 0; index < layout.row.length; index++) {
        final positionCode = layout.row[index];
        final verticalOffset = _verticalOffsetForPositionCode(
          positionCode,
          layout.spotHeight,
        );

        final top = (rowTop + verticalOffset)
            .clamp(6.0, constraints.maxHeight - layout.spotHeight - 6.0)
            .toDouble();

        widgets.add(
          Positioned(
            left: layout.lefts[index],
            top: top,
            width: layout.spotWidth,
            height: layout.spotHeight,
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

    final usableLeft =
        (centerX - (rowSpan / 2)).clamp(8.0, constraints.maxWidth).toDouble();
    final usableRight = (centerX + (rowSpan / 2))
        .clamp(0.0, constraints.maxWidth - 8.0)
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
    final horizontalPadding = 16.0 * 2;
    final maxUsableSpan = maxWidth - horizontalPadding;

    if (count == 1) {
      return spotWidth;
    }

    final isOnlyWidePair =
        count == 2 && row.contains('ES') && row.contains('ED');

    if (isOnlyWidePair) {
      return (maxWidth * 0.46).clamp(
        spotWidth * 2.4,
        maxUsableSpan,
      ).toDouble();
    }

    final wideRoles = {'TS', 'TD', 'ES', 'ED', 'AS', 'AD'};
    final hasWideRoles = row.any(wideRoles.contains);

    final baseSpacingMultiplier = switch (count) {
      2 => hasWideRoles ? 1.55 : 1.25,
      3 => hasWideRoles ? 1.18 : 1.05,
      4 => 1.0,
      5 => 0.94,
      _ => 0.90,
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
      switch (positionCode) {
        case 'ES':
          return -(spotWidth * 0.10);
        case 'ED':
          return spotWidth * 0.10;
        default:
          return 0;
      }
    }

    return _horizontalOffsetForPositionCode(positionCode, spotWidth);
  }

  double _horizontalOffsetForPositionCode(String positionCode, double spotWidth) {
    switch (positionCode) {
      case 'TS':
        return -(spotWidth * 0.24);
      case 'TD':
        return spotWidth * 0.24;
      case 'ES':
        return -(spotWidth * 0.20);
      case 'ED':
        return spotWidth * 0.20;
      case 'AS':
        return -(spotWidth * 0.18);
      case 'AD':
        return spotWidth * 0.18;
      case 'CCS':
        return -(spotWidth * 0.12);
      case 'CCD':
        return spotWidth * 0.12;
      case 'CDCS':
        return -(spotWidth * 0.15);
      case 'CDCD':
        return spotWidth * 0.15;
      default:
        return 0;
    }
  }

  double _verticalOffsetForPositionCode(String positionCode, double spotHeight) {
    if (positionCode == 'COC' ||
        positionCode == 'COCS' ||
        positionCode == 'COCD') {
      return -(spotHeight * 0.16);
    }

    if (positionCode == 'CDCS' || positionCode == 'CDCD') {
      return spotHeight * 0.18;
    }

    if (positionCode == 'CCS' || positionCode == 'CCD') {
      return spotHeight * 0.06;
    }

    if (positionCode == 'CDC') {
      return spotHeight * 0.13;
    }

    return 0;
  }

  double _minimumVerticalOffsetForRow(List<String> row, double spotHeight) {
    var minOffset = 0.0;
    for (final positionCode in row) {
      final offset = _verticalOffsetForPositionCode(positionCode, spotHeight);
      if (offset < minOffset) {
        minOffset = offset;
      }
    }
    return minOffset;
  }

  double _maximumVerticalOffsetForRow(List<String> row, double spotHeight) {
    var maxOffset = 0.0;
    for (final positionCode in row) {
      final offset = _verticalOffsetForPositionCode(positionCode, spotHeight);
      if (offset > maxOffset) {
        maxOffset = offset;
      }
    }
    return maxOffset;
  }

  double _minimumHorizontalSeparation(int rowSize, double spotWidth) {
    return switch (rowSize) {
      2 => spotWidth * 0.28,
      3 => spotWidth * 0.18,
      4 => spotWidth * 0.10,
      5 => spotWidth * 0.06,
      _ => spotWidth * 0.08,
    };
  }

  double _minimumVerticalSeparation(double maxHeight) {
    return (maxHeight * 0.035).clamp(8.0, 18.0).toDouble();
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

  List<double> _resolveRowTops({
    required List<_RowLayoutData> rows,
    required double maxHeight,
    required double goalkeeperHeight,
  }) {
    if (rows.isEmpty) {
      return const <double>[];
    }

    final indexed = rows.asMap().entries.map((entry) {
      return (index: entry.key, data: entry.value);
    }).toList();

    indexed.sort((a, b) => a.data.desiredTop.compareTo(b.data.desiredTop));

    final sortedTops = indexed.map((e) => e.data.desiredTop).toList();
    final minVerticalSpacing = _minimumVerticalSeparation(maxHeight);

    final topBoundary = 6.0;
    final bottomBoundary = maxHeight - goalkeeperHeight - 24.0;

    for (var i = 0; i < indexed.length; i++) {
      final row = indexed[i].data;
      final minTop = topBoundary - row.minOffset;
      final maxTop = bottomBoundary - row.spotHeight - row.maxOffset;
      sortedTops[i] = sortedTops[i].clamp(minTop, maxTop).toDouble();
    }

    for (var i = 1; i < indexed.length; i++) {
      final previous = indexed[i - 1].data;
      final current = indexed[i].data;

      final previousBottom =
          sortedTops[i - 1] + previous.spotHeight + previous.maxOffset;
      final currentTop = sortedTops[i] + current.minOffset;

      final minAllowedTop =
          previousBottom + minVerticalSpacing - current.minOffset;

      if (currentTop < previousBottom + minVerticalSpacing) {
        sortedTops[i] = minAllowedTop;
      }
    }

    for (var i = indexed.length - 1; i >= 0; i--) {
      final row = indexed[i].data;
      final maxTop = bottomBoundary - row.spotHeight - row.maxOffset;
      if (sortedTops[i] > maxTop) {
        final overflow = sortedTops[i] - maxTop;
        for (var j = 0; j <= i; j++) {
          sortedTops[j] -= overflow;
        }
      }
    }

    for (var i = indexed.length - 2; i >= 0; i--) {
      final current = indexed[i].data;
      final next = indexed[i + 1].data;

      final currentBottom =
          sortedTops[i] + current.spotHeight + current.maxOffset;
      final nextTop = sortedTops[i + 1] + next.minOffset;
      final maxAllowedTop =
          nextTop - minVerticalSpacing - current.spotHeight - current.maxOffset;

      if (currentBottom > nextTop - minVerticalSpacing) {
        sortedTops[i] = maxAllowedTop;
      }
    }

    for (var i = 0; i < indexed.length; i++) {
      final row = indexed[i].data;
      final minTop = topBoundary - row.minOffset;
      final maxTop = bottomBoundary - row.spotHeight - row.maxOffset;
      sortedTops[i] = sortedTops[i].clamp(minTop, maxTop).toDouble();
    }

    final backToOriginalOrder = List<double>.filled(rows.length, 0);
    for (var i = 0; i < indexed.length; i++) {
      backToOriginalOrder[indexed[i].index] = sortedTops[i];
    }

    return backToOriginalOrder;
  }

  Widget _buildGoalkeeper(
    BoxConstraints constraints,
    double spotWidth,
    double spotHeight,
  ) {
    return Positioned(
      left: (constraints.maxWidth * 0.5) - (spotWidth / 2),
      top: (constraints.maxHeight * 0.85) - (spotHeight / 2),
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

  List<double> _rowTopFractions(int rowCount) {
    if (rowCount <= 0) return const [];
    if (rowCount == 1) return const [0.46];

    const start = 0.68;
    const end = 0.16;

    return List<double>.generate(
      rowCount,
      (index) => start - ((start - end) * index / (rowCount - 1)),
    );
  }

  double _horizontalGap(int itemCount) {
    return switch (itemCount) {
      5 => 6,
      4 => 8,
      _ => 10,
    };
  }

  double _spotWidthForRow(
    double totalWidth,
    int itemCount,
    double gap,
  ) {
    const sidePadding = 18.0;
    final availableWidth =
        totalWidth - (sidePadding * 2) - (gap * (itemCount - 1));
    final calculatedWidth = (availableWidth / itemCount) * 0.96;
    return calculatedWidth.clamp(50.0, 88.0).toDouble();
  }

  double _spotHeightForWidth(double spotWidth, double maxHeight) {
    final calculatedHeight = spotWidth * 0.78;
    final heightCap = (maxHeight * 0.14).clamp(48.0, 70.0).toDouble();
    return calculatedHeight.clamp(48.0, heightCap).toDouble();
  }
}

class _RowLayoutData {
  const _RowLayoutData({
    required this.row,
    required this.lefts,
    required this.spotWidth,
    required this.spotHeight,
    required this.desiredTop,
    required this.minOffset,
    required this.maxOffset,
  });

  final List<String> row;
  final List<double> lefts;
  final double spotWidth;
  final double spotHeight;
  final double desiredTop;
  final double minOffset;
  final double maxOffset;
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
          ? colorScheme.surface.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 64 || constraints.maxWidth < 70;
            final ultraCompact =
                constraints.maxHeight < 60 || constraints.maxWidth < 78;
            final showFullName =
                hasPlayer && !ultraCompact && constraints.maxHeight >= 68;
            final primaryLabel =
                hasPlayer ? player!.idConsoleDisplay : 'Scegli';

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ultraCompact ? 5 : 7,
                vertical: ultraCompact ? 4 : 6,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ultraCompact ? 5 : 7,
                        vertical: ultraCompact ? 1.5 : 3,
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
                              fontSize: ultraCompact ? 9 : compact ? 10 : 11,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(height: ultraCompact ? 1 : compact ? 3 : 5),
                  Expanded(
                    child: Center(
                      child: Text(
                        primaryLabel,
                        maxLines: ultraCompact ? 1 : compact ? 1 : 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight:
                                  hasPlayer ? FontWeight.w600 : FontWeight.w400,
                              fontSize: ultraCompact ? 10 : compact ? 11 : 12,
                              height: 1.0,
                            ),
                      ),
                    ),
                  ),
                  if (showFullName)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        player!.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
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
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );

    canvas.drawRRect(outer, fillPaint);
    canvas.drawRRect(outer, linePaint);

    final halfY = size.height / 2;
    canvas.drawLine(Offset(0, halfY), Offset(size.width, halfY), linePaint);

    final center = Offset(size.width / 2, halfY);
    canvas.drawCircle(center, size.width * 0.12, linePaint);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);

    final topBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.12),
      width: size.width * 0.46,
      height: size.height * 0.14,
    );
    final bottomBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.88),
      width: size.width * 0.46,
      height: size.height * 0.14,
    );
    canvas.drawRect(topBox, linePaint);
    canvas.drawRect(bottomBox, linePaint);

    final topSmallBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.06),
      width: size.width * 0.22,
      height: size.height * 0.07,
    );
    final bottomSmallBox = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.94),
      width: size.width * 0.22,
      height: size.height * 0.07,
    );
    canvas.drawRect(topSmallBox, linePaint);
    canvas.drawRect(bottomSmallBox, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}