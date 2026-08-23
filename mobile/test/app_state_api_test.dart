
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:samapoche/data/api_client.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/state/app_state.dart';

import 'mock_adapter.dart';

/// Tests d'intégration d'AppState contre une API simulée :
/// vérifie le câblage signup -> bootstrap -> mutations.
void main() {
  late MockAdapter mock;
  late MemTokenStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mock = MockAdapter();
    store = MemTokenStore();
    final s = AppState.I;
    s.api = ApiClient(baseUrl: 'http://mock', tokenStore: store)
      ..dio.httpClientAdapter = mock;
    await s.forceSignOut();

    // Réponses serveur par défaut
    mock.reply('POST', '/auth/register', 201,
        {'access_token': 'jwt-abc', 'token_type': 'bearer'});
    mock.reply(
        'POST', '/auth/login', 200, {'access_token': 'jwt-abc', 'token_type': 'bearer'});
    mock.reply('GET', '/auth/me',
        200, {'id': 1, 'email': 'awa@afi.sn', 'full_name': 'Awa Diop'});
    mock.reply('GET', '/categories', 200, [
      {'id': 1, 'name': 'Alimentation', 'icon': 'restaurant', 'color': '#FF6B6B'},
      {'id': 8, 'name': 'Salaire', 'icon': 'work', 'color': '#3EC70B'},
      {'id': 9, 'name': 'Autres', 'icon': 'more_horiz', 'color': '#A8A8A8'},
    ]);
    mock.reply('GET', '/transactions', 200, [
      {
        'id': 5,
        'user_id': 1,
        'amount': 5000.0,
        'type': 'expense',
        'description': 'Courses',
        'category_id': 1,
        'transaction_date':
            DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }
    ]);
    mock.reply('GET', '/budgets', 200, []);
    mock.reply('GET', '/dashboard/balance', 200, {
      'balance': -5000.0,
      'total_income': 0.0,
      'total_expenses': 5000.0,
      'month_income': 0.0,
      'month_expenses': 5000.0,
    });
  });

  test('signup -> profil, catégories, transactions et agrégats chargés',
      () async {
    final err = await AppState.I
        .signup(const UserProfile(firstName: 'Awa', lastName: 'Diop', email: 'awa@afi.sn', phone: '77'), 'motdepasse8');
    expect(err, isNull);
    expect(store.token, 'jwt-abc');
    expect(AppState.I.user?.email, 'awa@afi.sn');
    expect(AppState.I.user?.firstName, 'Awa');
    expect(AppState.I.user?.lastName, 'Diop');
    expect(AppState.I.categoryIds['Alimentation'], 1);
    expect(AppState.I.transactions.length, 1);
    expect(AppState.I.transactions.first.category, 'Alimentation');
    // Agrégats serveur préférentiels
    expect(AppState.I.monthExpense, 5000);
  });

  test('mauvais identifiants -> message renvoyé, pas de token', () async {
    mock.reply('POST', '/auth/login', 401,
        {'detail': 'Email ou mot de passe incorrect'});
    final err = await AppState.I.login('awa@afi.sn', 'faux');
    expect(err, 'Email ou mot de passe incorrect');
    expect(store.token, isNull);
    expect(AppState.I.user, isNull);
  });

  test('addTxn crée côté API et insère la réponse serveur', () async {
    await AppState.I.signup(
        const UserProfile(firstName: 'Awa', lastName: 'Diop', email: 'awa@afi.sn', phone: ''), 'motdepasse8');

    mock.reply('POST', '/transactions', 201, {
      'id': 42,
      'user_id': 1,
      'amount': 15000.0,
      'type': 'income',
      'description': 'Vente',
      'category_id': 8,
      'transaction_date': DateTime.now().toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final t = Txn(
      id: 'local-temp',
      name: 'Vente',
      category: 'Salaire',
      type: TxnType.income,
      amount: 15000,
      description: 'Vente',
      payment: '',
      date: DateTime.now(),
    );
    await AppState.I.addTxn(t);

    final body = sentJson(mock, 'POST', '/transactions')!;
    expect(body['category_id'], 8); // id serveur de « Salaire »
    expect(body['type'], 'income');

    // L'id local est remplacé par l'id serveur
    expect(AppState.I.transactions.any((x) => x.id == '42'), isTrue);
    expect(AppState.I.transactions.any((x) => x.id == 'local-temp'), isFalse);
  });

  test('setBudget crée le budget Alimentation côté serveur', () async {
    await AppState.I.signup(
        const UserProfile(firstName: 'Awa', lastName: 'Diop', email: 'awa@afi.sn', phone: ''), 'motdepasse8');

    var created = false;
    mock.on('POST', '/budgets', (_) {
      created = true;
      return (
        201,
        {
          'id': 9,
          'user_id': 1,
          'category_id': 1,
          'amount': 200000.0,
          'month': DateTime.now().month,
          'year': DateTime.now().year,
          'created_at': DateTime.now().toIso8601String(),
        }
      );
    });
    // Après création, GET /budgets renvoie la ligne avec la consommation
    mock.on('GET', '/budgets', (_) => created
        ? (
            200,
            [
              {
                'id': 9,
                'category_id': 1,
                'category_name': 'Alimentation',
                'amount': 200000.0,
                'spent': 5000.0,
                'percentage': 2.5,
                'alert_80': false,
                'alert_100': false,
                'remaining': 195000.0,
              }
            ]
          )
        : (200, <Object>[]));

    await AppState.I.setBudget(200000);

    expect(created, isTrue);
    expect(sentJson(mock, 'POST', '/budgets')!['amount'], 200000.0);
    expect(AppState.I.budgetSpent, 5000); // dépense serveur
    expect(AppState.I.budgetRemaining, 195000);
  });

  test('token expiré au démarrage -> session nettoyée', () async {
    await AppState.I.signup(
        const UserProfile(firstName: 'Awa', lastName: 'Diop', email: 'awa@afi.sn', phone: ''), 'motdepasse8');
    expect(store.token, 'jwt-abc');

    // Simule un redémarrage avec un token invalide : /me répond 401
    mock.reply('GET', '/auth/me', 401, {'detail': 'Token expiré'});
    SharedPreferences.setMockInitialValues({});

    final s = AppState.I;
    s.api = ApiClient(baseUrl: 'http://mock', tokenStore: store)
      ..dio.httpClientAdapter = mock;
    await s.init(); // store contient encore jwt-abc

    // Session purgée après échec de restauration
    expect(s.user, isNull);
    expect(store.token, isNull);
    expect(s.transactions, isEmpty);
  });
}
