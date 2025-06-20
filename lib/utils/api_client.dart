import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maymap_mobile/utils/storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String baseUrl = 'http://localhost:8000/api';

  Future<http.Response> get(String endpoint) async {
    final token = await SecureStorage.getToken();
    return await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> post(String endpoint, dynamic body) async {
    final token = await SecureStorage.getToken();
    return await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );
  }

// Ajoutez d'autres méthodes (put, delete, etc.) selon vos besoins
}