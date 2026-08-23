import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samapoche/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Parcours E2E : l\'application démarre', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SamaPocheApp());
    await tester.pumpAndSettle();

    expect(find.text('SamaPoche'), findsOneWidget);
    expect(find.text('Gérez mieux. Économisez plus.'), findsOneWidget);
  });

  testWidgets('Parcours E2E : inscription et retour', (tester) async {
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
