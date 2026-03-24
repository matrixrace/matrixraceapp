import 'package:shared_preferences/shared_preferences.dart';

/// Persiste uma URL de retorno no localStorage (sobrevive a page reloads).
/// Usado para redirecionar o usuário após login/registro quando veio de um
/// link compartilhado (ex: /join/ABC123).
class PendingRedirectService {
  static const _key = 'pending_redirect_url';

  /// Salva a URL de retorno.
  static Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url);
  }

  /// Retorna e limpa a URL pendente (null se não houver).
  static Future<String?> consumeRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_key);
    if (url != null) {
      await prefs.remove(_key);
    }
    return url;
  }

  /// Limpa a URL pendente sem retornar.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
