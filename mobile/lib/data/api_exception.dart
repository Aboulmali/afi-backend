import 'package:dio/dio.dart';

/// Erreur API normalisée avec un message affichable à l'utilisateur.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;

    // FastAPI : {"detail": "..."} ou {"detail": [{msg, ...}, ...]}
    String? detail;
    if (data is Map<String, dynamic>) {
      final d = data['detail'];
      if (d is String) {
        detail = d;
      } else if (d is List && d.isNotEmpty && d.first is Map) {
        detail = (d.first as Map)['msg']?.toString();
      }
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return ApiException('Serveur injoignable. Vérifiez votre connexion.',
          statusCode: code);
    }
    switch (code) {
      case 400:
      case 401:
      case 403:
        return ApiException(detail ?? 'Accès refusé', statusCode: code);
      case 404:
        return ApiException(detail ?? 'Ressource introuvable', statusCode: code);
      case 422:
        return ApiException(detail ?? 'Données invalides', statusCode: code);
      default:
        return ApiException(
          detail ?? 'Une erreur est survenue (${code ?? 'réseau'}).',
          statusCode: code,
        );
    }
  }
}
