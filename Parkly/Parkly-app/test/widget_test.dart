import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/main.dart';

void main() {
  testWidgets('App branding smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    // MyApp initializes AuthWrapper which shows Splash screen first.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that our branding "Parkly" is present on the splash screen.
    expect(find.text('Parkly'), findsOneWidget);

    // 3. Verify the presence of the Parking Icon
    expect(find.byIcon(Icons.local_parking_rounded), findsOneWidget);

    // 4. Force widget disposal to cancel the 2-second timer.
    // This prevents the "A Timer is still pending" error without
    // waiting for the timer to finish and triggering Firebase logic.
    await tester.pumpWidget(const SizedBox());
  });
}
