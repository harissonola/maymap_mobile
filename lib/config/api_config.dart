// lib/config/api_config.dart

class ApiConfig {
  // Configuration de base - changez cette URL selon votre environnement
  static const String baseUrl = 'http://localhost:8000';

  // URLs des API endpoints
  static const String apiUrl = '$baseUrl/api';

  // URLs pour les images
  static const String usersImageUrl = '$baseUrl/users';
  static const String establishmentsImageUrl = '$baseUrl/establishments';
  static const String postsImageUrl = '$baseUrl/posts';

  // Endpoints API
  static const String loginEndpoint = '$apiUrl/auth/login';
  static const String registerEndpoint = '$apiUrl/auth/register';
  static const String feedEndpoint = '$apiUrl/posts/feed';
  static const String postsEndpoint = '$apiUrl/posts';
  static const String likesEndpoint = '$apiUrl/posts/{id}/like';
  static const String commentsEndpoint = '$apiUrl/posts/{id}/comments';

  // Headers par défaut
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers avec authentification
  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };

  // Méthode pour construire les URLs d'images
  static String buildImageUrl(String? imagePath, ImageType type) {
    if (imagePath == null || imagePath.isEmpty) return '';

    // Si c'est déjà une URL complète, la retourner telle quelle
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Nettoyer le chemin
    String cleanPath = _cleanImagePath(imagePath);

    // Construire l'URL selon le type
    switch (type) {
      case ImageType.user:
        return '$usersImageUrl/$cleanPath';
      case ImageType.establishment:
        return '$establishmentsImageUrl/$cleanPath';
      case ImageType.post:
        return '$postsImageUrl/$cleanPath';
    }
  }

  // Méthode privée pour nettoyer les chemins d'images
  static String _cleanImagePath(String imagePath) {
    String cleanPath = imagePath;

    // Enlever les préfixes indésirables
    if (cleanPath.startsWith('file://')) {
      cleanPath = cleanPath.substring(7);
    }

    // Enlever les chemins absolus qui commencent par /
    if (cleanPath.startsWith('/')) {
      // Extraire juste le nom du fichier si c'est un chemin complet
      List<String> pathParts = cleanPath.split('/');
      cleanPath = pathParts.last;
    }

    return cleanPath;
  }

  // Méthode pour vérifier si une URL est valide
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    return url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.contains('.');
  }
}

enum ImageType {
  user,
  establishment,
  post,
}