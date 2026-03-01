/// Configurações globais do app
class AppConfig {
  // URL da API do backend
  // Em desenvolvimento: http://localhost:3000
  // Em produção: trocar para URL do Railway
  static const String apiBaseUrl = 'https://www.matrixrace.com/api/v1';

  // Nome do app
  static const String appName = 'F1 Predictions';

  // Versão
  static const String version = '1.0.0';

  // Pontuação máxima por palpite correto
  static const int maxPoints = 20;
}
