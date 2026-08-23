import 'package:shared_preferences/shared_preferences.dart';

/// Stockage du token JWT, abstrait pour pouvoir être remplacé
/// (ex. flutter_secure_storage) sans toucher au reste du code.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class PrefsTokenStore implements TokenStore {
  static const _key = 'afi_jwt';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
