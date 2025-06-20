import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'client_profile_screen.dart';
import 'establishment_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          setState(() {
            _userData = jsonData['user'];
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _errorMessage = 'Erreur de format des données';
            _isLoading = false;
          });
          await _storage.delete(key: 'auth_token');
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur de chargement du profil';
          _isLoading = false;
        });
        await _storage.delete(key: 'auth_token');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion';
        _isLoading = false;
      });
      await _storage.delete(key: 'auth_token');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      return const Scaffold(
        body: Center(child: Text('Erreur de chargement du profil')),
      );
    }

    final roles = _userData!['roles'] as List<dynamic>? ?? [];

    if (roles.contains('ROLE_ESTABLISHMENT')) {
      return EstablishmentProfileScreen(userData: _userData!);
    } else {
      return ClientProfileScreen(userData: _userData!);
    }
  }
}