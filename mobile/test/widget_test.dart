import 'package:flutter_test/flutter_test.dart';

import 'package:samapoche/main.dart';

void main() {
  testWidgets("L'app SamaPoche se lance", (WidgetTester tester) async {
    await tester.pumpWidget(const SamaPocheApp());

    expect(find.text('SamaPoche'), findsOneWidget);
  });
}
