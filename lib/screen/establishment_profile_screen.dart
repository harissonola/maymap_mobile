// establishment_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class EstablishmentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EstablishmentProfileScreen({super.key, required this.userData});

  @override
  State<EstablishmentProfileScreen> createState() => _EstablishmentProfileScreenState();
}

class _EstablishmentProfileScreenState extends State<EstablishmentProfileScreen> {
  final _storage = const FlutterSecureStorage();
  late Map<String, dynamic> userData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
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
        setState(() {
          userData = json.decode(response.body)['user'];
          isLoading = false;
        });
      } else {
        _handleError('Failed to load profile data');
      }
    } catch (e) {
      _handleError('Connection error');
    }
  }

  void _handleError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final establishment = userData['establishment'] as Map<String, dynamic>? ?? {};

    return DefaultTabController(
        length: 4,
        child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
        title: Text(
        establishment['name'] ?? 'Mon Établissement',
        style: TextStyle(
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
        shadows: isDark
        ? [const Shadow(color: Colors.black, blurRadius: 4)]
        : null,
    ),
    ),
    centerTitle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
    icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary),
      onPressed: () => Navigator.of(context).pushNamed('/home'),
    ),
    actions: [
    IconButton(
    icon: Icon(Icons.edit, color: theme.colorScheme.onPrimary),
    onPressed: () => Navigator.of(context).pushNamed('/establishment/manage'),
    ),
    IconButton(
    icon: Icon(Icons.refresh, color: theme.colorScheme.onPrimary),
    onPressed: _refreshData,
    ),
    ],
    bottom: PreferredSize(
    preferredSize: const Size.fromHeight(48),
    child: Container(
    decoration: BoxDecoration(
    color: theme.colorScheme.surface.withOpacity(0.8),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
    child: TabBar(
    indicator: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    color: theme.colorScheme.primary,
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: theme.colorScheme.onPrimary,
    unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
    tabs: [
    Tab(icon: Icon(Icons.info_outline, size: 24)),
    Tab(icon: Icon(Icons.photo_library_outlined, size: 24)),
    Tab(icon: Icon(Icons.schedule_outlined, size: 24)),
    Tab(icon: Icon(Icons.article_outlined, size: 24)),
    ],
    ),
    ),
    ),
    ),
    body: Stack(
    children: [
    // Background image
    _buildHeaderImage(establishment, theme),

    // Content
    Padding(
    padding: const EdgeInsets.only(top: 180),
    child: Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: TabBarView(
    children: [
    _buildInfoTab(establishment, theme),
    _buildGalleryTab(establishment, theme),
    _buildScheduleTab(establishment, theme),
    _buildPostsTab(establishment, theme),
    ],
    ),
    ),
    ),
    ],
    ),
    floatingActionButton: FloatingActionButton(
    backgroundColor: theme.colorScheme.primary,
    onPressed: () => _callEstablishment(establishment['telephone']),
    child: Icon(Icons.call, color: theme.colorScheme.onPrimary),
    ),
    ),
    );
  }

  Widget _buildHeaderImage(Map<String, dynamic> establishment, ThemeData theme) {
    final images = establishment['images'] as List<dynamic>? ?? [];
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
            : LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.7),
            theme.colorScheme.secondary.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: images.isNotEmpty
          ? Image.network(
        'http://localhost:8000/establishments/${images[0]['imageUrl']}',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(),
      )
          : Container(),
    );
  }

  Future<void> _callEstablishment(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }

    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'appeler $phoneNumber')),
      );
    }
  }

  Widget _buildInfoTab(Map<String, dynamic> establishment, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verified & Premium badges
            _buildBadges(establishment, theme),

            // Description
            _buildSection(
              title: 'Description',
              content: establishment['description'] ?? 'Aucune description disponible',
              theme: theme,
            ),

            // Contact Information
            _buildSection(
              title: 'Informations de contact',
              content: Column(
                children: [
                  _buildContactInfo(Icons.location_on, establishment['address'], theme),
                  _buildContactInfo(Icons.phone, establishment['telephone'], theme),
                  _buildContactInfo(Icons.email, userData['email'], theme),
                ],
              ),
              theme: theme,
            ),

            // Location
            _buildSection(
              title: 'Localisation',
              content: SizedBox(
                height: 200,
                child: _buildMap(establishment, theme),
              ),
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(Map<String, dynamic> establishment, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        children: [
          if (establishment['isVerified'] == true)
            Chip(
              label: Text('VERIFIÉ', style: TextStyle(color: theme.colorScheme.onPrimary)),
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          if (establishment['isPremium'] == true)
            Chip(
              label: Text('PREMIUM', style: TextStyle(color: Colors.amber[900])),
              backgroundColor: Colors.amber[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required dynamic content, required ThemeData theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (content is String)
          Text(
            content,
            style: theme.textTheme.bodyMedium,
          )
        else
          content,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMap(Map<String, dynamic> establishment, ThemeData theme) {
    try {
      final locationData = establishment['location'];
      dynamic location;

      if (locationData is String) {
        location = jsonDecode(locationData);
      } else {
        location = locationData;
      }

      if (location == null || location is! Map<String, dynamic>) {
        return _buildNoLocationWidget(theme);
      }

      final lat = (location['latitude'] is num) ? (location['latitude'] as num).toDouble() : null;
      final lng = (location['longitude'] is num) ? (location['longitude'] as num).toDouble() : null;

      if (lat == null || lng == null) {
        return _buildNoLocationWidget(theme);
      }

      final marker = Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: Icon(Icons.location_pin, color: theme.colorScheme.primary, size: 40),
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(lat, lng),
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [marker],
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Erreur dans _buildMap: $e');
      return _buildNoLocationWidget(theme);
    }
  }

  Widget _buildNoLocationWidget(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('Localisation non disponible', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String? text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text ?? 'Non renseigné',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTab(Map<String, dynamic> establishment, ThemeData theme) {
    final images = establishment['images'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: images.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 50, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucune image disponible',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () => Navigator.of(context).pushNamed('/establishment/manage'),
              child: const Text('Ajouter des images'),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(
                '/image/view',
                arguments: images[index]['imageUrl'],
              ),
              child: Image.network(
                'http://localhost:8000/establishments/${images[index]['imageUrl']}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: theme.colorScheme.surfaceVariant),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleTab(Map<String, dynamic> establishment, ThemeData theme) {
    final horaires = (establishment['horaires'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    String formatTime(String? isoTime) {
      if (isoTime == null) return '--:--';
      try {
        final dateTime = DateTime.parse(isoTime).toLocal();
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return '--:--';
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Horaires d\'ouverture',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (horaires.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 50, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun horaire défini',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ...horaires.map((horaire) {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    horaire['jour']?.toString() ?? 'Jour',
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Text(
                    horaire['heureOuverture'] != null && horaire['heureFermeture'] != null
                        ? '${formatTime(horaire['heureOuverture'])} - ${formatTime(horaire['heureFermeture'])}'
                        : 'Fermé',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pushNamed('/establishment/manage'),
            child: const Text('Modifier les horaires'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(Map<String, dynamic> establishment, ThemeData theme) {
    final posts = establishment['posts'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: posts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article, size: 50, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucune actualité publiée',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: () => Navigator.of(context).pushNamed('/establishment/manage/posts'),
              child: const Text('Créer une actualité'),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final createdAt = DateTime.tryParse(post['createdAt'] ?? '')?.toLocal();

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'] ?? 'Titre',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['content'] ?? 'Contenu',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    createdAt != null
                        ? 'Publié le ${createdAt.toString().split(' ')[0]}'
                        : 'Date inconnue',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}