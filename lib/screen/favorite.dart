import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:maymap_mobile/model/establishment.dart';
import 'package:maymap_mobile/screen/login.dart'; // Correction du chemin d'import

class FavoriteService {
  final String _baseUrl = 'http://localhost:8000/api/favorites';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<List<Establishment>> getFavorites() async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Non authentifié');

    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Establishment.fromJson(e)).toList();
    } else {
      throw Exception('Échec du chargement des favoris');
    }
  }

  Future<bool> isFavorite(int establishmentId) async {
    final token = await _getAuthToken();
    if (token == null) return false;

    final response = await http.get(
      Uri.parse('$_baseUrl/check/$establishmentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['isFavorite'];
    } else {
      throw Exception('Échec de la vérification du favori');
    }
  }

  Future<bool> toggleFavorite(int establishmentId) async {
    final token = await _getAuthToken();
    if (token == null) throw Exception('Non authentifié');

    final isCurrentlyFavorite = await isFavorite(establishmentId);
    final response = isCurrentlyFavorite
        ? await http.delete(
      Uri.parse('$_baseUrl/$establishmentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    )
        : await http.post(
      Uri.parse('$_baseUrl/$establishmentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return response.statusCode == 200;
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Future<List<Establishment>> _favoritesFuture;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await _storage.read(key: 'auth_token');
    setState(() {
      _isLoggedIn = token != null;
      if (_isLoggedIn) {
        _favoritesFuture = _favoriteService.getFavorites();
      }
    });
  }

  Future<void> _refreshFavorites() async {
    if (_isLoggedIn) {
      setState(() {
        _favoritesFuture = _favoriteService.getFavorites();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
      ),
      body: _isLoggedIn ? _buildFavoritesList() : _buildLoginPrompt(),
    );
  }

  Widget _buildFavoritesList() {
    return RefreshIndicator(
      onRefresh: _refreshFavorites,
      child: FutureBuilder<List<Establishment>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun favori pour le moment'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final establishment = snapshot.data![index];
                return _buildFavoriteItem(establishment);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Connectez-vous pour voir vos favoris',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vos établissements favoris seront enregistrés une fois que vous serez connecté.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                ).then((_) => _checkLoginStatus());
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 15),
              ),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Establishment establishment) {
    return FutureBuilder<bool>(
      future: _favoriteService.isFavorite(establishment.id),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: establishment.images.isNotEmpty
                ? CircleAvatar(
              backgroundImage: NetworkImage(establishment.images.first),
            )
                : const CircleAvatar(
              child: Icon(Icons.place),
            ),
            title: Text(establishment.name),
            subtitle: Text(establishment.location),
            trailing: IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              onPressed: () async {
                final success = await _favoriteService.toggleFavorite(establishment.id);
                if (success) {
                  _refreshFavorites();
                }
              },
            ),
            onTap: () {
              // Navigation vers les détails de l'établissement
            },
          ),
        );
      },
    );
  }
}