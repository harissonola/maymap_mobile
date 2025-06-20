// lib/services/post_service.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class PostService {
  static const String _baseUrl = 'http://localhost:8000/api';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<dynamic>> getFeed() async {
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/posts/feed'), // Remplacez localhost par 10.0.2.2 pour Android
        headers: headers,
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is Map && jsonResponse['success'] == true) {
          return jsonResponse['data']; // Retourne seulement le tableau 'data'
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    String? title,
    List<String> images = const [],
  }) async {
    final token = await _storage.read(key: 'auth_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'content': content,
        'images': images,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create post: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> toggleLike(int postId) async {
    final token = await _storage.read(key: 'auth_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/like'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to toggle like');
    }
  }

  Future<List<dynamic>> getComments(int postId) async {
    final token = await _storage.read(key: 'auth_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/posts/$postId/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load comments');
    }
  }

  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    final token = await _storage.read(key: 'auth_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/posts/$postId/comments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'content': content}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add comment');
    }
  }
}