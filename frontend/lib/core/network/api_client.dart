import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';

/// Cliente HTTP para comunicação com o backend
/// Automaticamente adiciona o token Firebase em todas as requisições
class ApiClient {
  final String baseUrl = AppConfig.apiBaseUrl;

  // Pega o token do Firebase (se o usuário estiver logado)
  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  // Monta os headers com autenticação
  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
    };

    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // GET request
  Future<ApiResponse> get(String path) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erro de conexão: $e',
        statusCode: 0,
      );
    }
  }

  // POST request
  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erro de conexão: $e',
        statusCode: 0,
      );
    }
  }

  // PUT request
  Future<ApiResponse> put(String path, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erro de conexão: $e',
        statusCode: 0,
      );
    }
  }

  // DELETE request
  Future<ApiResponse> delete(String path) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erro de conexão: $e',
        statusCode: 0,
      );
    }
  }
}

/// Classe que representa a resposta da API
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
  });

  factory ApiResponse.fromResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return ApiResponse(
        success: body['success'] ?? false,
        message: body['message'] ?? '',
        data: body['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Erro ao processar resposta',
        statusCode: response.statusCode,
      );
    }
  }
}
