import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/utils/format.dart';

void main() {
  test('formatMontant ajoute des espaces', () {
    expect(formatMontant(0), '0');
    expect(formatMontant(500), '500');
    expect(formatMontant(1284500), '1 284 500');
    expect(formatMontant(-28500), '−28 500');
  });

  test('formatFCFA', () {
    expect(formatFCFA(150000), '150 000 F CFA');
  });

  test('formatDateListe', () {
    expect(formatDateListe(DateTime(2026, 7, 22)), '22 Juil 2026');
  });

  test('formatDateDetail', () {
    expect(formatDateDetail(DateTime(2026, 7, 22, 14, 30)), '22 Juil 2026, 14:30');
  });

  test('formatDateHome jours relatifs', () {
    final now = DateTime(2026, 7, 25, 10);
    expect(formatDateHome(DateTime(2026, 7, 25, 14, 30), now), "Aujourd'hui, 14:30");
    expect(formatDateHome(DateTime(2026, 7, 24, 8, 15), now), 'Hier, 08:15');
    expect(formatDateHome(DateTime(2026, 7, 14, 9, 0), now), 'Mar 14 Juil, 09:00');
  });

  test('montantSigne', () {
    expect(montantSigne(-28500), '−28 500 F');
    expect(montantSigne(450000), '+450 000 F');
  });
}
