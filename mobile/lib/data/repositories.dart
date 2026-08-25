import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_exception.dart';
import 'api_models.dart';

/// Repositories de l'API AFI. Chaque méthode lève une [ApiException]
/// en cas d'erreur (messages prêts à afficher).

class AuthRepository {
  final Dio _dio;
  AuthRepository(this._dio);

  Future<ApiToken> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final r = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'full_name': fullName,
      });
      return ApiToken.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiToken> login(String email, String password) async {
    try {
      final r = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return ApiToken.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiUser> me() async {
    try {
      final r = await _dio.get('/auth/me');
      return ApiUser.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class CategoryRepository {
  final Dio _dio;
  CategoryRepository(this._dio);

  Future<List<ApiCategory>> list() async {
    try {
      final r = await _dio.get('/categories');
      return (r.data as List)
          .map((e) => ApiCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class TransactionRepository {
  final Dio _dio;
  TransactionRepository(this._dio);

  /// Liste paginée (100 par page), suit le header X-Total-Count.
  Future<List<ApiTransaction>> list({int limit = 500}) async {
    try {
      final all = <ApiTransaction>[];
      var skip = 0;
      while (true) {
        final pageSize = limit - all.length < 100 ? limit - all.length : 100;
        final r = await _dio.get('/transactions',
            queryParameters: {'skip': skip, 'limit': pageSize});
        final page = (r.data as List)
            .map((e) => ApiTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
        all.addAll(page);
        if (page.length < pageSize || all.length >= limit) break;
        skip += pageSize;
      }
      return all;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiTransaction> create({
    required double amount,
    required TxnType type,
    required int categoryId,
    String? description,
    DateTime? date,
  }) async {
    try {
      final r = await _dio.post('/transactions', data: {
        'amount': amount,
        'type': type.name,
        'category_id': categoryId,
        'description': ?description,
        'transaction_date': ?date?.toUtc().toIso8601String(),
      });
      return ApiTransaction.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiTransaction> update({
    required int id,
    double? amount,
    String? description,
    int? categoryId,
  }) async {
    try {
      final r = await _dio.put('/transactions/$id', data: {
        'amount': ?amount,
        'description': ?description,
        'category_id': ?categoryId,
      });
      return ApiTransaction.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/transactions/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class BudgetRepository {
  final Dio _dio;
  BudgetRepository(this._dio);

  /// Statuts des budgets du mois (consommation + alertes incluses).
  Future<List<ApiBudgetStatus>> list({int? month, int? year}) async {
    try {
      final r = await _dio.get('/budgets', queryParameters: {
        'month': ?month,
        'year': ?year,
      });
      return (r.data as List)
          .map((e) => ApiBudgetStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> create({
    required int categoryId,
    required double amount,
    required int month,
    required int year,
  }) async {
    try {
      await _dio.post('/budgets', data: {
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateAmount(int id, double amount) async {
    try {
      await _dio.put('/budgets/$id', data: {'amount': amount});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/budgets/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class DashboardRepository {
  final Dio _dio;
  DashboardRepository(this._dio);

  Future<ApiBalance> balance() async {
    try {
      final r = await _dio.get('/dashboard/balance');
      return ApiBalance.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
