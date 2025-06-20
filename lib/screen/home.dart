// lib/screens/home.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maymap_mobile/screen/user_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/post_service.dart';
import '../utils/image_url_helper.dart';
import 'establishment_post_profile_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PostService _postService = PostService();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await _postService.getFeed();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Erreur de chargement: $e'); // Ajoutez ceci pour le débogage
      _showSnackBar('Erreur de chargement des publications: ${e.toString()}');
    }
  }

  void _navigateToProfile(BuildContext context, Map<String, dynamic> author) {
    final isEstablishment = author['type'] == 'establishment';
  
    Navigator.pushNamed(
      context,
      isEstablishment ? '/establishmentProfile' : '/userProfile',
      arguments: {
        isEstablishment ? 'establishmentId' : 'userId': author['id'].toString()
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.isEmpty) return const SizedBox();

    if (images.length == 1) {
      final imageUrl = ImageUrlHelper.buildPostImageUrl(images.first);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? Image.network(
          imageUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.grey),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
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
        )
            : Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    if (images.length == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: _buildSingleImage(images[0]),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _buildSingleImage(images[1]),
              ),
            ],
          ),
        ),
      );
    }

    if (images.length == 3) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 250,
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: _buildSingleImage(images[0]),
              ),
              const SizedBox(height: 2),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSingleImage(images[1]),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _buildSingleImage(images[2]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: _buildSingleImage(images[0]),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSingleImage(images[1]),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSingleImage(images[2]),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                        ),
                        child: Center(
                          child: Text(
                            '+${images.length - 2}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed,
      {bool isLiked = false, Color? color}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: isLiked
                ? Colors.red
                : (color ?? theme.iconTheme.color?.withOpacity(0.8)),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareModal(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bottomSheetTheme.backgroundColor,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Partager ce post',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    Icons.chat,
                    'WhatsApp',
                    Colors.green,
                    onTap: () => _shareViaWhatsApp(post),
                  ),
                  _buildShareOption(
                    Icons.facebook,
                    'Facebook',
                    const Color(0xFF1877F2),
                    onTap: () => _shareViaFacebook(post),
                  ),
                  _buildShareOption(
                    Icons.camera_alt,
                    'Instagram',
                    const Color(0xFFE4405F),
                    onTap: () => _shareViaInstagram(post),
                  ),
                  _buildShareOption(
                    Icons.alternate_email,
                    'Twitter',
                    const Color(0xFF1DA1F2),
                    onTap: () => _shareViaTwitter(post),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    Icons.email,
                    'Email',
                    Colors.orange,
                    onTap: () => _shareViaEmail(post),
                  ),
                  _buildShareOption(
                    Icons.telegram,
                    'Telegram',
                    const Color(0xFF0088CC),
                    onTap: () => _shareViaTelegram(post),
                  ),
                  _buildShareOption(
                    Icons.message,
                    'SMS',
                    Colors.green[700]!,
                    onTap: () => _shareViaSMS(post),
                  ),
                  _buildShareOption(
                    Icons.more_horiz,
                    'Autres',
                    theme.iconTheme.color ?? Colors.grey,
                    onTap: () => _shareViaOthers(post),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _buildShareText(Map<String, dynamic> post) {
    final author = post['author'];
    final content = post['content'];
    return 'Découvrez ce post de ${author['name']} :\n\n"$content"\n\nVia VotreApp';
  }

  Future<void> _shareViaWhatsApp(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post));
    final whatsappUrl = 'whatsapp://send?text=$text';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        _showSnackBar('WhatsApp n\'est pas installé');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du partage WhatsApp');
    }
  }

  Future<void> _shareViaFacebook(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post));
    final facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=https://votreapp.com/posts/${post['id']}&quote=$text';

    try {
      if (await canLaunchUrl(Uri.parse(facebookUrl))) {
        await launchUrl(Uri.parse(facebookUrl), mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Impossible d\'ouvrir Facebook');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du partage Facebook');
    }
  }

  Future<void> _shareViaInstagram(Map<String, dynamic> post) async {
    Navigator.pop(context);
    const instagramUrl = 'instagram://app';

    try {
      if (await canLaunchUrl(Uri.parse(instagramUrl))) {
        await launchUrl(Uri.parse(instagramUrl));
        _showSnackBar('Instagram ouvert - Vous pouvez maintenant créer votre story');
      } else {
        _showSnackBar('Instagram n\'est pas installé');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture d\'Instagram');
    }
  }

  Future<void> _shareViaTwitter(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post));
    final twitterUrl = 'https://twitter.com/intent/tweet?text=$text&url=https://votreapp.com/posts/${post['id']}';

    try {
      if (await canLaunchUrl(Uri.parse(twitterUrl))) {
        await launchUrl(Uri.parse(twitterUrl), mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Impossible d\'ouvrir Twitter');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du partage Twitter');
    }
  }

  Future<void> _shareViaTelegram(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post));
    final telegramUrl = 'https://t.me/share/url?url=https://votreapp.com/posts/${post['id']}&text=$text';

    try {
      if (await canLaunchUrl(Uri.parse(telegramUrl))) {
        await launchUrl(Uri.parse(telegramUrl));
      } else {
        _showSnackBar('Telegram n\'est pas installé');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du partage Telegram');
    }
  }

  Future<void> _shareViaEmail(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final subject = Uri.encodeComponent('Découvrez ce post intéressant');
    final body = Uri.encodeComponent(_buildShareText(post) + '\n\nLien: https://votreapp.com/posts/${post['id']}');
    final emailUrl = 'mailto:?subject=$subject&body=$body';

    try {
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        _showSnackBar('Aucune application email configurée');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture de l\'email');
    }
  }

  Future<void> _shareViaSMS(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent('${_buildShareText(post)}\n\nhttps://votreapp.com/posts/${post['id']}');
    final smsUrl = 'sms:?body=$text';

    try {
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      } else {
        _showSnackBar('Impossible d\'ouvrir l\'application SMS');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture SMS');
    }
  }

  Future<void> _shareViaOthers(Map<String, dynamic> post) async {
    Navigator.pop(context);
    try {
      final text = _buildShareText(post) + '\n\nhttps://votreapp.com/posts/${post['id']}';
      _showSnackBar('Fonctionnalité de partage système à implémenter');
    } catch (e) {
      _showSnackBar('Erreur lors du partage');
    }
  }

  Widget _buildShareOption(IconData icon, String label, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return GestureDetector(
                    onTap: () => _showPostDetailModal(post),
                    child: _buildPost(
                      post: post,
                      onLike: () => _handleLike(post['id']),
                      onComment: () => _showCommentsModal(post['id']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostDetailModal(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bottomSheetTheme.backgroundColor,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return PostDetailModal(
              post: post,
              onLike: () => _handleLike(post['id']),
              onComment: () => _showCommentsModal(post['id']),
              onShare: () => _showShareModal(post),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.article_outlined,
                size: 60,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune publication disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Soyez le premier à partager quelque chose ou suivez plus de personnes pour voir leurs publications.',
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Actualiser',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPost({
    required Map<String, dynamic> post,
    required VoidCallback onLike,
    required VoidCallback onComment,
  }) {
    final theme = Theme.of(context);
    final author = post['author'];
    final images = List<String>.from(post['images'] ?? []);
    final isEstablishment = author['type'] == 'establishment'; // Modification ici
    final avatarUrl = ImageUrlHelper.buildAvatarUrl(author['avatar'], isEstablishment);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isEstablishment
            ? Border.all(color: theme.colorScheme.secondary.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(context, author),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Icon(Icons.person, size: 20, color: theme.iconTheme.color)
                            : null,
                      ),
                      if (isEstablishment)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.cardColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.business,
                              size: 12,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(context, author),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              author['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.textTheme.titleMedium?.color,
                              ),
                            ),
                            if (isEstablishment)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: theme.colorScheme.secondary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Établissement',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          _formatTimeAgo(post['createdAt']),
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.more_vert, color: theme.iconTheme.color),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post['content'],
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
                fontStyle: isEstablishment ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildImageGrid(images),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildActionButton(
                  post['isLiked'] ? Icons.favorite : Icons.favorite_outline,
                  '${post['likeCount']}',
                  onLike,
                  isLiked: post['isLiked'],
                  color: isEstablishment ? theme.colorScheme.secondary : null,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.chat_bubble_outline,
                  '${post['commentCount']}',
                  onComment,
                  color: isEstablishment ? theme.colorScheme.secondary : null,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.share_outlined,
                  'Partager',
                      () => _showShareModal(post),
                  color: isEstablishment ? theme.colorScheme.secondary : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jours';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heures';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minutes';
    } else {
      return 'À l\'instant';
    }
  }

  Future<void> _handleLike(int postId) async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      final result = await _postService.toggleLike(postId);
      _showSnackBar(result['isLiked'] ? 'Post liké' : 'Like retiré');
      _loadPosts();
    } catch (e) {
      _showSnackBar('Erreur lors du like');
    }
  }

  void _showCommentsModal(int postId) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bottomSheetTheme.backgroundColor,
      builder: (context) => CommentsModal(postId: postId),
    );
  }
}

class PostDetailModal extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const PostDetailModal({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = post['author'];
    final images = List<String>.from(post['images'] ?? []);
    final isEstablishment = author['type'] == 'establishment'; // Modification ici
    final avatarUrl = ImageUrlHelper.buildAvatarUrl(author['avatar'], isEstablishment);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du post
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? Icon(Icons.person, size: 20, color: theme.iconTheme.color)
                                  : null,
                            ),
                            if (isEstablishment)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.cardColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    size: 12,
                                    color: theme.colorScheme.onSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    author['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.textTheme.titleMedium?.color,
                                    ),
                                  ),
                                  if (isEstablishment)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: theme.colorScheme.secondary.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          'Établissement',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                _formatTimeAgo(post['createdAt']),
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.more_vert, color: theme.iconTheme.color),
                      ],
                    ),
                  ),

                  // Contenu du post
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      post['content'],
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.textTheme.bodyMedium?.color,
                        fontStyle: isEstablishment ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Images en pleine largeur
                  if (images.isNotEmpty)
                    Column(
                      children: images.map((image) {
                        final imageUrl = ImageUrlHelper.buildPostImageUrl(image);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error, color: Colors.grey),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
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
                            )
                                : Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildActionButton(
                          context, // Ajoutez ce paramètre
                          post['isLiked'] ? Icons.favorite : Icons.favorite_outline,
                          '${post['likeCount']}',
                          onLike,
                          isLiked: post['isLiked'],
                          color: isEstablishment ? theme.colorScheme.secondary : null,
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          context,
                          Icons.chat_bubble_outline,
                          '${post['commentCount']}',
                          onComment,
                          color: isEstablishment ? theme.colorScheme.secondary : null,
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          context,
                          Icons.share_outlined,
                          'Partager',
                          onShare,
                          color: isEstablishment ? theme.colorScheme.secondary : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onPressed,
      {bool isLiked = false, Color? color}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: isLiked
                ? Colors.red
                : (color ?? theme.iconTheme.color?.withOpacity(0.8)),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jours';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heures';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minutes';
    } else {
      return 'À l\'instant';
    }
  }
}

Widget _buildSingleImage(String imageUrl) {
  final correctedUrl = ImageUrlHelper.buildPostImageUrl(imageUrl);

  return correctedUrl.isNotEmpty
      ? Image.network(
    correctedUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (context, error, stackTrace) => Container(
      color: Colors.grey[300],
      child: const Icon(Icons.error, color: Colors.grey),
    ),
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
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
  )
      : Container(
    color: Colors.grey[300],
    child: const Icon(Icons.image_not_supported, color: Colors.grey),
  );
}

class CommentsModal extends StatefulWidget {
  final int postId;

  const CommentsModal({super.key, required this.postId});

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _postService.getComments(widget.postId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de chargement des commentaires')),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      await _postService.addComment(widget.postId, _commentController.text);
      _commentController.clear();
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ajout du commentaire')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Commentaires',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                  : ListView.builder(
                controller: scrollController,
                itemCount: _comments.length,
                itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        hintStyle: TextStyle(color: theme.hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final theme = Theme.of(context);
    final author = comment['author'];
    final isEstablishment = author['type'] == 'establishment';
    final avatarUrl = ImageUrlHelper.buildAvatarUrl(author['avatar'], isEstablishment);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _navigateToProfile(context, author),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 16, color: theme.iconTheme.color)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        author['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(comment['createdAt']),
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment['content'],
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes}min';
    } else {
      return 'À l\'instant';
    }
  }
}

void _navigateToProfile(BuildContext context, Map<String, dynamic> author) {
  final isEstablishment = author['type'] == 'establishment';

  if (isEstablishment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EstablishmentProfileScreen(
            establishmentId: author['id'].toString()
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
            userId: author['id'].toString()
        ),
      ),
    );
  }
}