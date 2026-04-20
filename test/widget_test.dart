import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app placeholder shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Clubline'),
        ),
      ),
    );

    expect(find.text('Clubline'), findsOneWidget);
  });
}
