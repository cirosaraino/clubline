import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app placeholder shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Squadra App'),
        ),
      ),
    );

    expect(find.text('Squadra App'), findsOneWidget);
  });
}
