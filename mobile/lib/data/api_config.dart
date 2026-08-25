/// Configuration de l'API AFI.
///
/// L'URL de base peut être surchargée à la compilation :
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000`
class ApiConfig {
  ApiConfig._();

  /// 10.0.2.2 = localhost de la machine hôte vu depuis l'émulateur Android.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiPrefix = '/api/v1';
}
