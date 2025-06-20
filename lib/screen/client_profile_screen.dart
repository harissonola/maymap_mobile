import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../utils/image_url_helper.dart';

class ClientProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ClientProfileScreen({super.key, required this.userData});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _storage = const FlutterSecureStorage();
  late Map<String, dynamic> userData;
  List<dynamic> posts = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    posts = widget.userData['posts'] as List<dynamic>? ?? [];
    if (kDebugMode) {
      print(posts);
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/user'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (kDebugMode) {
          print('Response data: $responseData');
        }

        setState(() {
          userData = responseData['user'] ?? responseData;
          posts = responseData['posts'] ?? [];
          isLoading = false;
        });
      } else {
        _handleError('Failed to load profile data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing data: $e');
      }
      _handleError('Connection error');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mon Profil'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.of(context).pushNamed('/client/profile/edit'),
            ),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.refresh),
              onPressed: isLoading ? null : _refreshData,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profil'),
              Tab(text: 'Mes Posts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildPostsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildFavoritesSection(),
            const SizedBox(height: 24),
            _buildRecentRatings(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: posts.isEmpty
          ? _buildEmptyState(
        icon: Icons.article,
        message: 'Vous n\'avez publié aucun post',
        actionText: 'Créer un post',
        onAction: () => Navigator.of(context).pushNamed('/create-post'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildPostItem(post);
        },
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final images = _extractImageUrls(post['images']);
    final isLiked = post['isLiked'] ?? false;
    final likeCount = post['likeCount'] ?? 0;
    final commentCount = post['commentCount'] ?? 0;

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: userData['avatar'] != null
                      ? NetworkImage(ImageUrlHelper.buildAvatarUrl(userData['avatar'], false))
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${userData['fname'] ?? ''} ${userData['lname'] ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(post['createdAt'] ?? ''),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post['content'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
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
                  isLiked ? Icons.favorite : Icons.favorite_outline,
                  '$likeCount',
                      () => _handleLike(post['id']),
                  isLiked: isLiked,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.chat_bubble_outline,
                  '$commentCount',
                      () => _showCommentsModal(post['id']),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.share_outlined,
                  'Partager',
                      () => _showShareModal(post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractImageUrls(dynamic imagesData) {
    if (imagesData == null) return [];
    if (imagesData is String) return [imagesData];
    if (imagesData is List) {
      return imagesData
          .where((item) => item is String)
          .map((item) => item as String)
          .toList();
    }
    return [];
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
        )
            : Container(
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: images.length > 4 ? 4 : images.length,
          itemBuilder: (context, index) {
            final imageUrl = ImageUrlHelper.buildPostImageUrl(images[index]);

            if (index == 3 && images.length > 4) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, color: Colors.grey),
                    ),
                  )
                      : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: Center(
                      child: Text(
                        '+${images.length - 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error, color: Colors.grey),
              ),
            )
                : Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, {bool isLiked = false}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: isLiked ? Colors.red : theme.iconTheme.color?.withOpacity(0.8),
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
    try {
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
    } catch (e) {
      return 'Date inconnue';
    }
  }

  Future<void> _handleLike(int postId) async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    try {
      setState(() {
        final postIndex = posts.indexWhere((p) => p['id'] == postId);
        if (postIndex != -1) {
          posts[postIndex]['isLiked'] = !(posts[postIndex]['isLiked'] ?? false);
          if (posts[postIndex]['isLiked']) {
            posts[postIndex]['likeCount'] = (posts[postIndex]['likeCount'] ?? 0) + 1;
          } else {
            posts[postIndex]['likeCount'] = (posts[postIndex]['likeCount'] ?? 1) - 1;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du like')),
      );
    }
  }

  void _showCommentsModal(int postId) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bottomSheetTheme.backgroundColor,
      builder: (context) => _buildCommentsModal(postId),
    );
  }

  Widget _buildCommentsModal(int postId) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Commentaires',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fonctionnalité de commentaires à implémenter',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
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

  String _buildShareText(Map<String, dynamic> post) {
    final content = post['content'] ?? '';
    return 'Découvrez mon post :\n\n"$content"\n\nVia VotreApp';
  }

  Future<void> _shareViaWhatsApp(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post));
    final whatsappUrl = 'whatsapp://send?text=$text';

    try {
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp n\'est pas installé')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage WhatsApp')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir Facebook')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage Facebook')),
      );
    }
  }

  Future<void> _shareViaInstagram(Map<String, dynamic> post) async {
    Navigator.pop(context);
    const instagramUrl = 'instagram://app';

    try {
      if (await canLaunchUrl(Uri.parse(instagramUrl))) {
        await launchUrl(Uri.parse(instagramUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instagram ouvert - Vous pouvez maintenant créer votre story')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instagram n\'est pas installé')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ouverture d\'Instagram')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir Twitter')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage Twitter')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram n\'est pas installé')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage Telegram')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune application email configurée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ouverture de l\'email')),
      );
    }
  }

  Future<void> _shareViaSMS(Map<String, dynamic> post) async {
    Navigator.pop(context);
    final text = Uri.encodeComponent(_buildShareText(post) + '\n\nhttps://votreapp.com/posts/${post['id']}');
    final smsUrl = 'sms:?body=$text';

    try {
      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application SMS')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'ouverture SMS')),
      );
    }
  }

  Future<void> _shareViaOthers(Map<String, dynamic> post) async {
    Navigator.pop(context);
    try {
      final text = _buildShareText(post) + '\n\nhttps://votreapp.com/posts/${post['id']}';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fonctionnalité de partage système à implémenter')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du partage')),
      );
    }
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: userData['avatar'] != null
              ? NetworkImage(ImageUrlHelper.buildAvatarUrl(userData['avatar'], false))
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${userData['fname'] ?? ''} ${userData['lname'] ?? ''}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '@${userData['username'] ?? 'unknown'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  userData['isVerified'] == true ? 'Compte vérifié' : 'Compte non vérifié',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: userData['isVerified'] == true ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.favorite,
              color: Colors.pink,
              value: (userData['favoritesCount'] ?? 0).toString(),
              label: 'Favoris',
            ),
            _buildStatItem(
              icon: Icons.star,
              color: Colors.amber,
              value: (userData['ratingsCount'] ?? 0).toString(),
              label: 'Avis',
            ),
            _buildStatItem(
              icon: Icons.article,
              color: Colors.blue,
              value: posts.length.toString(),
              label: 'Posts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    final favorites = (userData['favorites'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mes favoris',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        favorites.isEmpty
            ? _buildEmptyState(
          icon: Icons.favorite_border,
          message: 'Vous n\'avez aucun favori',
          actionText: 'Explorer',
          onAction: () => Navigator.of(context).pushNamed('/categories'),
        )
            : SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return _buildFavoriteCard(favorite);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        '/establishment',
        arguments: favorite['id'],
      ),
      child: Card(
        margin: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: favorite['images'] != null &&
                    (favorite['images'] as List).isNotEmpty
                    ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: Image.network(
                    'http://localhost:8000/establishments/${favorite['images'][0]['imageUrl']}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.store, size: 50),
                  ),
                )
                    : const Icon(Icons.store, size: 50),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite['name'] ?? 'Établissement',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          (favorite['averageRating']?.toStringAsFixed(1) ?? '0'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRatings() {
    final ratings = (userData['ratings'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mes avis récents',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ratings.isEmpty
            ? _buildEmptyState(
          icon: Icons.comment,
          message: 'Vous n\'avez posté aucun avis',
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return _buildRatingItem(rating);
          },
        ),
      ],
    );
  }

  Widget _buildRatingItem(Map<String, dynamic> rating) {
    final establishment = rating['establishment'] as Map<String, dynamic>? ?? {};
    final createdAt = DateTime.tryParse(rating['createdAt'] ?? '')?.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    establishment['name'] ?? 'Établissement',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < (rating['note'] ?? 0) ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(rating['comment'] ?? ''),
            const SizedBox(height: 8),
            Text(
              createdAt != null
                  ? 'Le ${createdAt.toString().split(' ')[0]}'
                  : 'Date inconnue',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}