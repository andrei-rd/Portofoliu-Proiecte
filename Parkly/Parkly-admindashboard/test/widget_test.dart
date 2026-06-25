import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/main.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    // Folosim varianta moderna pentru Mocking Method Channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/firebase_core'), (MethodCall methodCall) async {
      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          }
        };
      }
      return null;
    });
  });

  testWidgets('Verificare incarcare Admin Dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.textContaining('Parkly Admin'), findsOneWidget);
  });
}
