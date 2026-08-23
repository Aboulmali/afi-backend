import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:samapoche/data/token_store.dart';

/// Adaptateur HTTP factice pour tester les repositories sans serveur.
///
/// Routes déclarées sous la forme `'GET /auth/me'`, `'POST /transactions'`.
/// Le handler reçoit les [RequestOptions] et renvoie `(code, body)`.
class MockAdapter implements HttpClientAdapter {
  final Map<String, (int, Object) Function(RequestOptions)> _routes = {};
  final List<RequestOptions> calls = [];

  void on(String method, String path,
      (int, Object) Function(RequestOptions opts) handler) {
    _routes['$method $path'] = handler;
  }

  void reply(String method, String path, int code, Object body) {
    on(method, path, (_) => (code, body));
  }

  bool called(String method, String path) =>
      calls.any((c) => c.method == method && c.uri.path.endsWith(path));

  Map<String, dynamic>? jsonBodyOf(String method, String path) {
    for (final c in calls) {
      if (c.method == method && c.uri.path.endsWith(path)) {
        final raw = (c.data as ResponseBody?)?.toString();
        return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      }
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    // Corps JSON de la requête (String ou Map selon le stade de sérialisation)
    final data = options.data;
    if (data is String && data.isNotEmpty) {
      options.extra['__json__'] = jsonDecode(data);
    } else if (data is Map) {
      options.extra['__json__'] = Map<String, dynamic>.from(data);
    }

    // Normalise le chemin : retire le préfixe /api/v1 du baseUrl
    var path = options.uri.path;
    const prefix = '/api/v1';
    if (path.startsWith(prefix)) path = path.substring(prefix.length);

    final key = '${options.method} $path';
    final handler = _routes[key];
    if (handler == null) {
      return _body(404, {'detail': 'MockAdapter: route inconnue $key'});
    }
    final (code, body) = handler(options);
    return _body(code, body);
  }

  static ResponseBody _body(int code, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Accès au corps JSON d'une requête capturée par le MockAdapter.
Map<String, dynamic>? sentJson(MockAdapter adapter, String method, String path) {
  for (final c in adapter.calls.reversed) {
    if (c.method == method && c.uri.path.endsWith(path)) {
      final raw = c.extra['__json__'];
      if (raw is Map<String, dynamic>) return raw;
      if (raw is String && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
      return null;
    }
  }
  return null;
}

/// TokenStore en mémoire pour les tests.
class MemTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}
