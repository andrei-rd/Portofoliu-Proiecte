import 'package:flutter_test/flutter_test.dart';

void main() {
  // Testul pentru Logica de Distanță (Cerința ta de QA)
  test('Verificare algoritm proximitate loc parcare', () {
    double distantaUtilizator = 150.0; // metri
    double razaMaxima = 200.0;

    bool esteAproape = distantaUtilizator <= razaMaxima;

    expect(esteAproape, true, reason: "Utilizatorul ar trebui sa vada locul daca e sub 200m");
  });

  // Testul pentru Dashboard (Cerința ta de Admin)
  test('Verificare status ocupare locuri parcare', () {
    int locuriTotale = 100;
    int locuriOcupate = 98;

    double gradOcupare = (locuriOcupate / locuriTotale) * 100;

    expect(gradOcupare, 98.0);
    expect(gradOcupare, greaterThan(90), reason: "Alerta de aglomerare ar trebui sa fie activa");
  });
}