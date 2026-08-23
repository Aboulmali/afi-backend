import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samapoche/main.dart';

void main() {
  testWidgets('L\'app démarre sur l\'écran Welcome', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SamaPocheApp());
    await tester.pumpAndSettle();

    expect(find.text('SamaPoche'), findsOneWidget);
    expect(find.text("S'identifier"), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);
  });

  testWidgets('Navigation Welcome -> Signup -> retour', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SamaPocheApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Rejoignez SamaPoche en un instant'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);
  });
}
