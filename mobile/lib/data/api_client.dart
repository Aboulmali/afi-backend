import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_store.dart';

/// Client HTTP authentifié : injecte le header `Authorization: Bearer`
/// sur chaque requête et notifie en cas de session expirée (401).
class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

  /// Appelé quand le serveur répond 401 sur une route protégée
  /// (token expiré/invalide) : l'app réinitialise la session.
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
        final t = _cachedToken;
        if (t != null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        final path = e.requestOptions.path.toString();
        final isAuthRoute =
            path.contains('/auth/login') || path.contains('/auth/register');
        // 401 sur route protégée = token invalide/expiré -> reset session.
        // Les 401 de login sont des erreurs d'identifiants, on ne déconnecte pas.
        if (status == 401 && !isAuthRoute) {
          _cachedToken = null;
          await store.clear();
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  /// Enregistre le token après register/login réussi.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await tokenStore.write(token);
  }

  /// Oublie le token (logout).
  Future<void> forgetToken() async {
    _cachedToken = null;
    await tokenStore.clear();
  }

  /// Précharge le token depuis le store (appelé au démarrage).
  Future<void> warmUp() async {
    _cachedToken ??= await tokenStore.read();
  }
}
