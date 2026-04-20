import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubline/core/lineup_constants.dart';
import 'package:clubline/core/lineup_pitch_layouts.dart';
import 'package:clubline/models/player_profile.dart';
import 'package:clubline/ui/widgets/lineup_pitch_view.dart';

Widget _buildPitch({
  required String module,
  required ValueChanged<String> onTap,
}) {
  final positions = lineupPositionCodesFor(module);
  final assigned = <String, PlayerProfile?>{
    for (final code in positions)
      code: PlayerProfile(
        id: code,
        nome: 'Nome',
        cognome: code,
        idConsole: code,
        primaryRole: preferredRoleForPositionCode(code),
      ),
  };

  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 390,
          height: 720,
          child: LineupPitchView(
            formationModule: module,
            selectedPlayersByPosition: assigned,
            onTapPosition: onTap,
            enabled: true,
          ),
        ),
      ),
    ),
  );
}

Rect _rectForPositionCode(WidgetTester tester, String code) {
  final codeText = find.text(code, findRichText: true).first;
  final spot = find.ancestor(
    of: codeText,
    matching: find.byType(InkWell),
  );
  expect(spot, findsAtLeastNWidgets(1));
  return tester.getRect(spot.first);
}

Rect _intersection(Rect a, Rect b) {
  final left = math.max(a.left, b.left);
  final right = math.min(a.right, b.right);
  final top = math.max(a.top, b.top);
  final bottom = math.min(a.bottom, b.bottom);

  if (right <= left || bottom <= top) {
    return Rect.zero;
  }

  return Rect.fromLTRB(left, top, right, bottom);
}

void _expectNoSpotOverlap(
  WidgetTester tester,
  List<String> codes,
) {
  final rects = <String, Rect>{
    for (final code in codes) code: _rectForPositionCode(tester, code),
  };

  for (var i = 0; i < codes.length; i++) {
    for (var j = i + 1; j < codes.length; j++) {
      final a = codes[i];
      final b = codes[j];
      final overlap = _intersection(rects[a]!, rects[b]!);
      expect(
        overlap.width * overlap.height,
        lessThanOrEqualTo(0.5),
        reason: 'Overlapping pitch slots detected: $a vs $b',
      );
    }
  }
}

void main() {
  group('LineupPitchView anti-overlap geometry', () {
    // Modules coverage: crowded rows, wide roles, and central split roles
    const modulesToCheck = <String>[
      '4-2-2-2',
      '4-2-3-1 LARGO',
      '4-3-3 IN LINEA',
      '3-5-2',
      '5-2-3',
    ];

    for (final module in modulesToCheck) {
      testWidgets('slots do not overlap for module $module', (tester) async {
        await tester.pumpWidget(_buildPitch(module: module, onTap: (_) {}));
        await tester.pumpAndSettle();

        final codes = lineupPositionCodesFor(module);
        _expectNoSpotOverlap(tester, codes);
      });
    }

    testWidgets('wide and split roles keep left/right ordering and separation', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPitch(module: '4-2-2-2', onTap: (_) {}));
      await tester.pumpAndSettle();

      final ts = _rectForPositionCode(tester, 'TS').center.dx;
      final dcs = _rectForPositionCode(tester, 'DCS').center.dx;
      final dcd = _rectForPositionCode(tester, 'DCD').center.dx;
      final td = _rectForPositionCode(tester, 'TD').center.dx;

      expect(ts < dcs && dcs < dcd && dcd < td, isTrue);

      final cdcs = _rectForPositionCode(tester, 'CDCS').center.dx;
      final cdcd = _rectForPositionCode(tester, 'CDCD').center.dx;
      expect(cdcs, lessThan(cdcd), reason: 'CDCS should remain left of CDCD');
      expect((cdcd - cdcs).abs(), greaterThan(8));

      final cocs = _rectForPositionCode(tester, 'COCS').center.dx;
      final cocd = _rectForPositionCode(tester, 'COCD').center.dx;
      expect(cocs, lessThan(cocd), reason: 'COCS should remain left of COCD');
      expect((cocd - cocs).abs(), greaterThan(8));
    });
  });

  group('LineupPitchView tap behavior', () {
    // Interaction coverage: verify taps still dispatch callbacks after layout compaction
    testWidgets('tapping spots emits correct position codes', (tester) async {
      final tappedCodes = <String>[];

      await tester.pumpWidget(
        _buildPitch(
          module: '4-2-2-2',
          onTap: tappedCodes.add,
        ),
      );
      await tester.pumpAndSettle();

      const targets = ['TS', 'CDCS', 'COCD', 'ATTD', 'POR'];
      for (final code in targets) {
        await tester.tap(find.text(code, findRichText: true).first);
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tappedCodes, containsAll(targets));
      expect(tappedCodes.length, equals(targets.length));
    });
  });
}
