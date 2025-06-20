// lib/utils/image_url_helper.dart

import 'package:flutter/material.dart';
import '../config/api_config.dart';

class ImageUrlHelper {
  /// Construit l'URL complète pour l'avatar d'un utilisateur
  static String buildUserAvatarUrl(String? imagePath) {
    return ApiConfig.buildImageUrl(imagePath, ImageType.user);
  }

  /// Construit l'URL complète pour l'avatar d'un établissement
  static String buildEstablishmentAvatarUrl(String? imagePath) {
    return ApiConfig.buildImageUrl(imagePath, ImageType.establishment);
  }

  /// Construit l'URL complète pour les images de posts
  static String buildPostImageUrl(String? imagePath) {
    return ApiConfig.buildImageUrl(imagePath, ImageType.post);
  }

  /// Construit l'URL d'avatar basée sur le type (utilisateur ou établissement)
  static String buildAvatarUrl(String? imagePath, bool isEstablishment) {
    if (isEstablishment) {
      return buildEstablishmentAvatarUrl(imagePath);
    } else {
      return buildUserAvatarUrl(imagePath);
    }
  }

  /// Vérifie si une URL d'image est valide
  static bool isValidImageUrl(String? url) {
    return ApiConfig.isValidImageUrl(url);
  }

  /// Nettoie et valide une URL d'image
  static String? cleanImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Si c'est un chemin file://, le nettoyer
    if (url.startsWith('file://')) {
      return url.substring(7);
    }

    return url;
  }

  /// Widget helper pour afficher une image avec gestion d'erreur
  static Widget buildNetworkImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty || !isValidImageUrl(imageUrl)) {
      return errorWidget ?? Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return placeholder ?? Container(
          width: width,
          height: height,
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.grey),
        );
      },
    );
  }
}