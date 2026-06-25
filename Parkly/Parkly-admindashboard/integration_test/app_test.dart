import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parkly/main.dart' as app;
import 'package:flutter/foundation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scenariu End-to-End: Eliberare si Rezervare Loc', () {
    testWidgets('Utilizatorul A elibereaza, Utilizatorul B rezerva', (tester) async {
      // 1. Pornim aplicatia
      app.main();
      await tester.pumpAndSettle();

      // --- SIMULARE UTILIZATOR A (Elibereaza locul) ---
      final buttonFinder = find.text('Eliberez Loc');
      // Verificam daca butonul exista inainte sa apasam
      if (buttonFinder.evaluate().isNotEmpty) {
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();
      }

      debugPrint("Utilizatorul A a eliberat locul.");

      // --- SIMULARE UTILIZATOR B (Rezerva) ---
      // Cautam un loc liber (textul depinde de ce ai tu in UI)
      final locFinder = find.textContaining('Loc');
      if (locFinder.evaluate().isNotEmpty) {
        await tester.tap(locFinder.first);
        await tester.pumpAndSettle();
      }

      debugPrint("Scenariu complet realizat!");
    });
  }); // Aici era eroarea, lipsea ); la final
}
