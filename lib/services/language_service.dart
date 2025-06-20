// lib/services/language_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LanguageService {
  static const String _baseUrl = 'http://localhost:8000/api';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Modèle pour les langues disponibles
  static const List<Language> availableLanguages = [
    Language(code: 'fr', name: 'Français', flag: '🇫🇷'),
    Language(code: 'en', name: 'English', flag: '🇺🇸'),
    Language(code: 'es', name: 'Español', flag: '🇪🇸'),
  ];

  /// Changer la langue de l'utilisateur connecté
  static Future<LanguageResponse> changeUserLanguage(String languageCode) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        return LanguageResponse(
          success: false,
          error: 'Token d\'authentification non trouvé',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/user/language'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'language': languageCode,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Sauvegarder la langue localement pour une utilisation hors ligne
        await _storage.write(key: 'user_language', value: languageCode);

        return LanguageResponse(
          success: true,
          message: responseData['message'] ?? 'Langue mise à jour avec succès',
          language: languageCode,
        );
      } else {
        return LanguageResponse(
          success: false,
          error: responseData['error'] ?? 'Erreur lors du changement de langue',
        );
      }
    } catch (e) {
      return LanguageResponse(
        success: false,
        error: 'Erreur de connexion au serveur: $e',
      );
    }
  }

  /// Obtenir la langue actuelle de l'utilisateur depuis le serveur
  static Future<LanguageResponse> getCurrentUserLanguage() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        // Retourner la langue locale si pas connecté
        final localLanguage = await getLocalLanguage();
        return LanguageResponse(
          success: true,
          language: localLanguage,
        );
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/user/language'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final language = responseData['data']['language'] ?? 'fr';

        // Sauvegarder localement
        await _storage.write(key: 'user_language', value: language);

        return LanguageResponse(
          success: true,
          language: language,
        );
      } else {
        // En cas d'erreur, utiliser la langue locale
        final localLanguage = await getLocalLanguage();
        return LanguageResponse(
          success: true,
          language: localLanguage,
        );
      }
    } catch (e) {
      // En cas d'erreur, utiliser la langue locale
      final localLanguage = await getLocalLanguage();
      return LanguageResponse(
        success: true,
        language: localLanguage,
      );
    }
  }

  /// Obtenir la langue sauvegardée localement
  static Future<String> getLocalLanguage() async {
    final language = await _storage.read(key: 'user_language');
    return language ?? 'fr'; // Français par défaut
  }

  /// Sauvegarder la langue localement
  static Future<void> saveLocalLanguage(String languageCode) async {
    await _storage.write(key: 'user_language', value: languageCode);
  }

  /// Obtenir toutes les langues disponibles depuis le serveur
  static Future<List<Language>> getAvailableLanguagesFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/languages'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final languagesData = responseData['data']['languages'] as List;
        return languagesData.map((lang) => Language.fromJson(lang)).toList();
      } else {
        // Retourner les langues par défaut en cas d'erreur
        return availableLanguages;
      }
    } catch (e) {
      // Retourner les langues par défaut en cas d'erreur
      return availableLanguages;
    }
  }

  /// Obtenir le nom de la langue à partir de son code
  static String getLanguageName(String code) {
    final language = availableLanguages.firstWhere(
          (lang) => lang.code == code,
      orElse: () => availableLanguages[0], // Français par défaut
    );
    return language.name;
  }

  /// Obtenir le drapeau de la langue à partir de son code
  static String getLanguageFlag(String code) {
    final language = availableLanguages.firstWhere(
          (lang) => lang.code == code,
      orElse: () => availableLanguages[0], // Français par défaut
    );
    return language.flag;
  }
}

// Modèles de données
class Language {
  final String code;
  final String name;
  final String flag;

  const Language({
    required this.code,
    required this.name,
    required this.flag,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      code: json['code'],
      name: json['name'],
      flag: json['flag'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'flag': flag,
    };
  }
}

class LanguageResponse {
  final bool success;
  final String? message;
  final String? error;
  final String? language;

  LanguageResponse({
    required this.success,
    this.message,
    this.error,
    this.language,
  });
}