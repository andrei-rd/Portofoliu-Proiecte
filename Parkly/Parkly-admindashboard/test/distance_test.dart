import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/utils/location_utils.dart';

void main() {
  group('QA - Testare Algoritmi Locație', () {

    test('Verificare distanță Universitate -> Unirii (~1.2km)', () {
      // Coordonate aproximative
      double latUniversitate = 44.4355;
      double lonUniversitate = 26.1025;

      double latUnirii = 44.4268;
      double lonUnirii = 26.1039;

      double distanta = LocationUtils.calculateDistance(
          latUniversitate, lonUniversitate,
          latUnirii, lonUnirii
      );

      // Verificăm dacă distanța este aproximativ 1.0 km (eroare acceptată 0.2km)
      // Nota: Distanța aeriană este de aprox 0.9 - 1.1 km
      expect(distanta, closeTo(1.0, 0.2));

      print('Test QA trecut: Distanța calculată este ${distanta.toStringAsFixed(2)} km');
    });

    test('Distanța între același punct trebuie să fie 0', () {
      double res = LocationUtils.calculateDistance(44.4, 26.1, 44.4, 26.1);
      expect(res, 0.0);
    });
  });
}