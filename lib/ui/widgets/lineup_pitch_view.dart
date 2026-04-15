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
    final rowTopFractions = _rowTopFractions(rows.length);
    final widgets = <Widget>[];

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

      final desiredLefts = List<double>.generate(row.length, (index) {
        final positionCode = row[index];
        final baseLeft = startLeft + (index * (rowSpotWidth + rowGap));
        final horizontalOffset = _horizontalOffsetForPositionCode(
          positionCode,
          rowSpotWidth,
        );
        return baseLeft + horizontalOffset;
      });

      final resolvedLefts = _resolveRowLefts(
        desiredLefts: desiredLefts,
        spotWidth: rowSpotWidth,
        minLeft: minLeft,
        maxLeft: maxLeft,
        minSpacing: minSpacing,
      );

      for (var index = 0; index < row.length; index++) {
        final positionCode = row[index];
        final baseTop = (constraints.maxHeight * topFraction) - (rowSpotHeight / 2);
        final verticalOffset = _verticalOffsetForPositionCode(
          positionCode,
          rowSpotHeight,
        );

        final left = resolvedLefts[index];
        final top = (baseTop + verticalOffset)
            .clamp(6.0, constraints.maxHeight - rowSpotHeight - 6.0)
            .toDouble();

        widgets.add(
          Positioned(
            left: left,
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

  double _minimumHorizontalSeparation(int rowSize, double spotWidth) {
    if (rowSize >= 5) {
      return spotWidth * 0.08;
    }

    if (rowSize == 4) {
      return spotWidth * 0.10;
    }

    return spotWidth * 0.12;
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

    final availableSpan = maxLeft - minLeft;
    final requiredSpan = (spotWidth * desiredLefts.length) +
        (minSpacing * (desiredLefts.length - 1));

    if (requiredSpan > availableSpan && desiredLefts.length > 1) {
      final compressedSpacing =
          ((availableSpan - (spotWidth * desiredLefts.length)) /
                  (desiredLefts.length - 1))
              .clamp(0.0, minSpacing)
              .toDouble();

      return List<double>.generate(
        desiredLefts.length,
        (index) => minLeft + (index * (spotWidth + compressedSpacing)),
      );
    }

    final resolved = desiredLefts
        .map((value) => value.clamp(minLeft, maxLeft).toDouble())
        .toList();

    for (var i = 1; i < resolved.length; i++) {
      final minimumCurrent = resolved[i - 1] + spotWidth + minSpacing;
      if (resolved[i] < minimumCurrent) {
        resolved[i] = minimumCurrent;
      }
    }

    if (resolved.last > maxLeft) {
      resolved[resolved.length - 1] = maxLeft;
      for (var i = resolved.length - 2; i >= 0; i--) {
        final maximumCurrent = resolved[i + 1] - spotWidth - minSpacing;
        if (resolved[i] > maximumCurrent) {
          resolved[i] = maximumCurrent;
        }
      }
    }

    if (resolved.first < minLeft) {
      final shiftRight = minLeft - resolved.first;
      for (var i = 0; i < resolved.length; i++) {
        resolved[i] += shiftRight;
      }
    }

    if (resolved.last > maxLeft) {
      final shiftLeft = resolved.last - maxLeft;
      for (var i = 0; i < resolved.length; i++) {
        resolved[i] -= shiftLeft;
      }
    }

    for (var i = 1; i < resolved.length; i++) {
      final minimumCurrent = resolved[i - 1] + spotWidth + minSpacing;
      if (resolved[i] < minimumCurrent) {
        resolved[i] = minimumCurrent;
      }
    }

    for (var i = 0; i < resolved.length; i++) {
      resolved[i] = resolved[i].clamp(minLeft, maxLeft).toDouble();
    }

    return resolved;
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
    final availableWidth = totalWidth - (sidePadding * 2) - (gap * (itemCount - 1));
    final calculatedWidth = (availableWidth / itemCount) * 0.96;
    return calculatedWidth.clamp(50.0, 88.0).toDouble();
  }

  double _spotHeightForWidth(double spotWidth, double maxHeight) {
    final calculatedHeight = spotWidth * 0.78;
    final heightCap = (maxHeight * 0.14).clamp(48.0, 70.0).toDouble();
    return calculatedHeight.clamp(48.0, heightCap).toDouble();
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
          ? colorScheme.surface.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 64 || constraints.maxWidth < 70;
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
