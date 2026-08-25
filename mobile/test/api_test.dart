import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samapoche/data/api_client.dart';
import 'package:samapoche/data/api_exception.dart';
import 'package:samapoche/data/api_models.dart';
import 'package:samapoche/data/repositories.dart';
import 'package:samapoche/models/models.dart';

import 'mock_adapter.dart';

void main() {
  late MockAdapter mock;
  late ApiClient client;

  setUp(() {
    mock = MockAdapter();
    client = ApiClient(
      baseUrl: 'http://mock',
      tokenStore: MemTokenStore(),
    );
    // Remplace l'adaptateur HTTP réel
    HttpClientAdapter injected = mock;
    client.dio.httpClientAdapter = injected;
  });

  group('AuthRepository', () {
    test('register envoie le bon payload et renvoie un token', () async {
      mock.reply('POST', '/auth/register', 201, {
        'access_token': 'jwt123',
        'token_type': 'bearer',
      });

      final repo = AuthRepository(client.dio);
      final token = await repo.register(
          email: 'awa@afi.sn', password: 'motdepasse8', fullName: 'Awa Diop');

      expect(token.accessToken, 'jwt123');
      final body = sentJson(mock, 'POST', '/auth/register')!;
      expect(body['email'], 'awa@afi.sn');
      expect(body['full_name'], 'Awa Diop');
      expect(body['password'], 'motdepasse8');
    });

    test('email déjà utilisé -> message FR', () async {
      mock.reply(
          'POST', '/auth/register', 400, {'detail': 'Cet email est déjà utilisé'});

      final repo = AuthRepository(client.dio);
      final err = await _err(() => repo.register(
          email: 'doublon@afi.sn', password: 'motdepasse8', fullName: 'Awa'));
      expect(err.message, 'Cet email est déjà utilisé');
      expect(err.statusCode, 400);
    });

    test('mauvais identifiants (401) -> message FR', () async {
      mock.reply('POST', '/auth/login', 401,
          {'detail': 'Email ou mot de passe incorrect'});

      final repo = AuthRepository(client.dio);
      final err =
          await _err(() => repo.login('awa@afi.sn', 'faux'));
      expect(err.message, 'Email ou mot de passe incorrect');
    });

    test('erreur de validation FastAPI 422 -> msg extrait', () async {
      mock.reply('POST', '/auth/login', 422, {
        'detail': [
          {'loc': ['body', 'email'], 'msg': 'value is not a valid email address'}
        ]
      });
      final repo = AuthRepository(client.dio);
      final err = await _err(() => repo.login('pasunemail', 'x'));
      expect(err.message, contains('valid email'));
    });

    test('/me parse le profil', () async {
      client.dio.options.headers['Authorization'] = 'Bearer jwt';
      mock.reply(
          'GET', '/auth/me', 200, {'id': 7, 'email': 'awa@afi.sn', 'full_name': 'Awa Diop'});
      final user = await AuthRepository(client.dio).me();
      expect(user.id, 7);
      expect(user.fullName, 'Awa Diop');
    });
  });

  group('TransactionRepository', () {
    const createdTxn = {
      'id': 10,
      'user_id': 1,
      'amount': 2500.0,
      'type': 'expense',
      'description': 'Thieboudienne',
      'category_id': 1,
      'transaction_date': '2026-08-23T12:00:00',
      'created_at': '2026-08-23T12:00:01',
    };

    test('create envoie category_id/type/date ISO et parse la réponse',
        () async {
      mock.reply('POST', '/transactions', 201, createdTxn);

      final txn = await TransactionRepository(client.dio).create(
        amount: 2500,
        type: TxnType.expense,
        categoryId: 1,
        description: 'Thieboudienne',
        date: DateTime.utc(2026, 8, 23, 12),
      );

      final body = sentJson(mock, 'POST', '/transactions')!;
      expect(body['amount'], 2500.0);
      expect(body['type'], 'expense');
      expect(body['category_id'], 1);
      expect(body['description'], 'Thieboudienne');

      expect(txn.id, 10);
      expect(txn.type, TxnType.expense);
      expect(txn.categoryId, 1);
    });

    test('ApiTransaction.toTxn mappe catégorie et fallback description',
        () async {
      final t = ApiTransaction.fromJson(createdTxn);
      final display = t.toTxn({1: 'Alimentation'});
      expect(display.name, 'Thieboudienne');
      expect(display.category, 'Alimentation');
      expect(display.amount, 2500);
      expect(display.type, TxnType.expense);

      final noDesc = ApiTransaction.fromJson({
        ...createdTxn,
        'description': null,
      }).toTxn({1: 'Alimentation'});
      expect(noDesc.name, 'Alimentation');
    });

    test('delete -> 204 sans corps', () async {
      mock.reply('DELETE', '/transactions/10', 204, '');
      await TransactionRepository(client.dio).delete(10);
      expect(mock.called('DELETE', '/transactions/10'), isTrue);
    });
  });

  group('BudgetRepository + DashboardRepository', () {
    test('list parse les alertes 80/100 et remaining', () async {
      mock.reply('GET', '/budgets', 200, [
        {
          'id': 3,
          'category_id': 1,
          'category_name': 'Alimentation',
          'amount': 150000.0,
          'spent': 130000.0,
          'percentage': 86.7,
          'alert_80': true,
          'alert_100': false,
          'remaining': 20000.0,
        }
      ]);
      final budgets = await BudgetRepository(client.dio).list(month: 8, year: 2026);
      expect(budgets.single.alert80, isTrue);
      expect(budgets.single.alert100, isFalse);
      expect(budgets.single.spent, 130000.0);
      expect(mock.calls.first.uri.queryParameters['month'], '8');
    });

    test('balance parse les agrégats dashboard', () async {
      mock.reply('GET', '/dashboard/balance', 200, {
        'balance': 47500.0,
        'total_income': 50000.0,
        'total_expenses': 2500.0,
        'month_income': 50000.0,
        'month_expenses': 2500.0,
      });
      final bal = await DashboardRepository(client.dio).balance();
      expect(bal.balance, 47500.0);
      expect(bal.monthExpenses, 2500.0);
    });
  });

  group('ApiClient', () {
    test('injecte le Bearer token depuis le TokenStore', () async {
      final store = MemTokenStore()..token = 'jwt-restauré';
      final c = ApiClient(baseUrl: 'http://mock', tokenStore: store)
        ..dio.httpClientAdapter = mock;
      mock.reply('GET', '/categories', 200, []);
      var unauthorized = false;
      c.onUnauthorized = () => unauthorized = true; // ne doit PAS être appelé ici
      await CategoryRepository(c.dio).list();
      expect(unauthorized, isFalse);
      expect(mock.calls.single.headers['Authorization'], 'Bearer jwt-restauré');
    });

    test('401 sur route protégée -> onUnauthorized + token effacé',
        () async {
      var unauthorizedCalled = false;
      final store = MemTokenStore()..token = 'jwt-expiré';
      final c = ApiClient(baseUrl: 'http://mock', tokenStore: store)
        ..dio.httpClientAdapter = mock;
      c.onUnauthorized = () => unauthorizedCalled = true;
      mock.reply('GET', '/transactions', 401, {'detail': 'Token expiré'});

      final err = await _err(() => TransactionRepository(c.dio).list());
      expect(err.statusCode, 401);
      expect(unauthorizedCalled, isTrue);
      expect(store.token, isNull);
    });

    test("401 sur login ne déclenche PAS onUnauthorized", () async {
      var unauthorizedCalled = false;
      final store = MemTokenStore()..token = 'jwt';
      final c = ApiClient(baseUrl: 'http://mock', tokenStore: store)
        ..dio.httpClientAdapter = mock;
      c.onUnauthorized = () => unauthorizedCalled = true;
      mock.reply('POST', '/auth/login', 401, {'detail': 'Email ou mot de passe incorrect'});

      await _err(() => AuthRepository(c.dio).login('a@b.sn', 'x'));
      expect(unauthorizedCalled, isFalse);
      expect(store.token, 'jwt'); // conservé
    });

    test('serveur injoignable -> message réseau', () async {
      client.dio.httpClientAdapter = _DeadAdapter();
      final err = await _err(() => CategoryRepository(client.dio).list());
      expect(err.message, contains('Serveur injoignable'));
    });
  });
}

Future<ApiException> _err(Future<Object?> Function() run) async {
  try {
    await run();
  } on ApiException catch (e) {
    return e;
  }
  fail('devait lever ApiException');
}

class _DeadAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );
  }
}
