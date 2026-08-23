import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_store.dart';

/// Client HTTP authentifié : injecte le header `Authorization: Bearer`
/// sur chaque requête et notifie en cas de session expirée (401).
class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

  /// Appelé quand le serveur répond 401 (token expiré/invalide).
  void Function()? onUnauthorized;

  String? _cachedToken;

  ApiClient({String baseUrl = ApiConfig.baseUrl, TokenStore? tokenStore})
      : tokenStore = tokenStore ?? PrefsTokenStore(),
        dio = Dio(BaseOptions(
          baseUrl: '$baseUrl${ApiConfig.apiPrefix}',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    final TokenStore store = this.tokenStore;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        _cachedToken ??= await store.read();
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(options);
      },
    ));
  }

  /// Traite les réponses 401 après coup.
  Future<Response<T>> guard<T>(Future<Response<T>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _cachedToken = null;
        onUnauthorized?.call();
      }
      rethrow;
    }
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await tokenStore.write(token);
  }

  Future<void> forgetToken() async {
    _cachedToken = null;
    await tokenStore.clear();
  }
}
