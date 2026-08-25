import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/data/api_client.dart';
import 'package:samapoche/data/api_exception.dart';
import 'package:samapoche/data/repositories.dart';
import 'package:samapoche/models/models.dart';

import 'mock_adapter.dart' show MemTokenStore;

/// Test d'intégration RÉEL contre le backend AFI lancé en local
/// (`docker compose up -d` à la racine du repo).
///
/// Exécution manuelle :
///   AFI_LIVE=1 flutter test test/api_integration_live_test.dart
/// URL surchargeable : AFI_LIVE_API_URL=http://localhost:8000
///
/// Sans AFI_LIVE=1, tous les tests sont skippés (CI GitHub inchangée).
void main() {
  final live = Platform.environment['AFI_LIVE'] == '1';
  final baseUrl =
      Platform.environment['AFI_LIVE_API_URL'] ?? 'http://localhost:8000';

  late ApiClient client;
  late AuthRepository auth;
  late CategoryRepository categories;
  late TransactionRepository txns;
  late BudgetRepository budgets;
  late DashboardRepository dashboard;

  Future<T> guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException catch (e) {
      fail('API inattendue: ${e.statusCode} ${e.message}');
    }
  }

  setUpAll(() async {
    client = ApiClient(baseUrl: baseUrl, tokenStore: MemTokenStore());
    auth = AuthRepository(client.dio);
    categories = CategoryRepository(client.dio);
    txns = TransactionRepository(client.dio);
    budgets = BudgetRepository(client.dio);
    dashboard = DashboardRepository(client.dio);
  });

  test('[live] health check répond', () async {
    if (!live) return;
    final r = await client.dio.getUri<Map<String, dynamic>>(
        Uri.parse('$baseUrl/health'));
    expect(r.data?['status'], 'healthy');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('[live] parcours complet register -> transaction -> budget', () async {
    if (!live) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'e2e.flutter.$stamp@afi.sn';

    // 1. Inscription -> token JWT immédiat (201)
    final token = await guard(() => auth.register(
        email: email, password: 'TestE2E#2026', fullName: 'Awa Diop Test'));
    await client.saveToken(token.accessToken);

    // 2. Profil /me
    final me = await guard(auth.me);
    expect(me.email, email);

    // 3. Catégories seedées par le backend
    final cats = await guard(categories.list);
    expect(cats, isNotEmpty);
    final ali = cats.singleWhere((c) => c.name == 'Alimentation');
    final salaire = cats.singleWhere((c) => c.name == 'Salaire');

    // 4. Créer une dépense puis un revenu
    await guard(() => txns.create(
        amount: 12000,
        type: TxnType.expense,
        categoryId: ali.id,
        description: 'Courses e2e',
        date: DateTime.now()));
    final income = await guard(() => txns.create(
        amount: 300000,
        type: TxnType.income,
        categoryId: salaire.id,
        description: 'Salaire e2e'));

    // 5. La liste serveur contient nos deux lignes
    final list = await guard(txns.list);
    expect(list.map((t) => t.id), contains(income.id));
    expect(list.where((t) => t.description == 'Courses e2e'), isNotEmpty);

    // 6. Agrégats dashboard cohérents avec les montants créés
    final bal = await guard(dashboard.balance);
    expect(bal.monthIncome, greaterThanOrEqualTo(300000));
    expect(bal.monthExpenses, greaterThanOrEqualTo(12000));

    // 7. Budget Alimentation du mois -> consommation > 0
    final now = DateTime.now();
    await guard(() => budgets.create(
        categoryId: ali.id,
        amount: 50000,
        month: now.month,
        year: now.year));
    final status = await guard(() => budgets.list(month: now.month, year: now.year));
    final aliStatus = status.where((b) => b.categoryName == 'Alimentation').toList();
    expect(aliStatus, isNotEmpty);
    expect(aliStatus.first.spent, greaterThanOrEqualTo(12000));

    // 8. Nettoyage (compte de test)
    for (final t in list) {
      await guard(() => txns.delete(t.id));
    }
    // 9. Logout côté client
    await client.forgetToken();
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('[live] login refuse un mauvais mot de passe', () async {
    if (!live) return;
    final err = await _expectApiError(
        () => auth.login('inconnu.e2e@afi.sn', 'nimporte'));
    expect(err.statusCode, anyOf(400, 401));
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<ApiException> _expectApiError(Future<Object?> Function() run) async {
  try {
    await run();
  } on ApiException catch (e) {
    return e;
  }
  fail('devait lever ApiException');
}
