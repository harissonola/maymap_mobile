import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> categories = [];
  bool isLoading = true;
  String errorMessage = '';
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentification requise';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List<dynamic> categoryList;
        if (data is List) {
          categoryList = data;
        } else if (data is Map && data.containsKey('data')) {
          categoryList = data['data'];
        } else {
          throw Exception('Format de réponse inattendu');
        }

        setState(() {
          categories = categoryList
              .map((category) => Category.fromJson(category))
              .toList();
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          isLoading = false;
          errorMessage = 'Session expirée, veuillez vous reconnecter';
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load categories: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800,
              Colors.grey.shade900,
            ],
          )
              : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Catégories',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    shadows: isDarkMode
                        ? [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black.withOpacity(0.5),
                      )
                    ]
                        : null,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? LinearGradient(
                      colors: [
                        Colors.blueGrey.shade900,
                        Colors.grey.shade800,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.lightBlue.shade200,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              elevation: 10,
              shadowColor: isDarkMode ? Colors.blueGrey : Colors.blue.shade200,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: isLoading
                  ? SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade600,
                    strokeWidth: 3,
                  ),
                ),
              )
                  : errorMessage.isNotEmpty
                  ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: isDarkMode ? Colors.red.shade300 : Colors.red.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (errorMessage.contains('Authentification') ||
                          errorMessage.contains('Session expirée'))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? Colors.blue.shade600
                                  : Colors.blue.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Se connecter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
                  : SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final category = categories[index];
                    return _buildCategoryItem(
                      context: context,
                      icon: _getIconForCategory(category.name),
                      iconColor: _getColorForCategory(index, isDarkMode),
                      title: category.name,
                      isDarkMode: isDarkMode,
                    );
                  },
                  childCount: categories.length,
                ),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? categoryName) {
    final iconMap = {
      'Santé & Bien êtres': FontAwesomeIcons.heartbeat,
      'Restaurants & Alimentations': FontAwesomeIcons.utensils,
      'Tourismes & Hébergements': FontAwesomeIcons.hotel,
      'Boutiques & Commerces': FontAwesomeIcons.shoppingBag,
      'Événements & Divertissements': FontAwesomeIcons.music,
      'Sports & Loisirs': FontAwesomeIcons.dumbbell,
      'Modes & Beautés': FontAwesomeIcons.cut,
      'Médias & Cultures': FontAwesomeIcons.book,
      'Informatiques & Technologies': FontAwesomeIcons.laptop,
      'Éducations & Formations': FontAwesomeIcons.graduationCap,
      'Banques & Finances': FontAwesomeIcons.university,
      'Mobilités & Transports': FontAwesomeIcons.bus,
      'BTP & Artisanats': FontAwesomeIcons.hammer,
      'Logements & Hébergements': FontAwesomeIcons.home,
      'Cultes & Religions': FontAwesomeIcons.pray,
      'Institutions & Services publics': FontAwesomeIcons.landmark,
      'Agricultures & Environnements': FontAwesomeIcons.seedling,
      'ONG, Associations Humanitaires': FontAwesomeIcons.handsHelping,
      'Industries & Productions': FontAwesomeIcons.industry,
    };

    return iconMap[categoryName] ?? FontAwesomeIcons.store;
  }

  Color _getColorForCategory(int index, bool isDarkMode) {
    final lightColors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE57373), // Red
      const Color(0xFFFFA726), // Orange
      const Color(0xFF4FC3F7), // Blue
      const Color(0xFFFFB74D), // Light Orange
      const Color(0xFFD4AF37), // Gold
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4DB6AC), // Teal
      const Color(0xFF7986CB), // Indigo
      const Color(0xFF64B5F6), // Light Blue
      const Color(0xFFFFF176), // Yellow
      const Color(0xFFFF8A65), // Deep Orange
      const Color(0xFFD32F2F), // Dark Red
      const Color(0xFFCD853F), // Brown
      const Color(0xFFBCAAA4), // Grey
      const Color(0xFF90A4AE), // Blue Grey
      const Color(0xFF66BB6A), // Light Green
      const Color(0xFFF48FB1), // Pink
      const Color(0xFFFF7043), // Deep Orange
    ];

    final darkColors = [
      const Color(0xFF81C784), // Light Green
      const Color(0xFFEF9A9A), // Light Red
      const Color(0xFFFFCC80), // Light Orange
      const Color(0xFF81D4FA), // Light Blue
      const Color(0xFFFFD54F), // Light Yellow
      const Color(0xFFE6C229), // Light Gold
      const Color(0xFFCE93D8), // Light Purple
      const Color(0xFF80CBC4), // Light Teal
      const Color(0xFF9FA8DA), // Light Indigo
      const Color(0xFF90CAF9), // Lighter Blue
      const Color(0xFFFFF59D), // Light Yellow
      const Color(0xFFFFAB91), // Light Deep Orange
      const Color(0xFFEF5350), // Light Red
      const Color(0xFFD7CCC8), // Light Brown
      const Color(0xFFEEEEEE), // Light Grey
      const Color(0xFFB0BEC5), // Light Blue Grey
      const Color(0xFFA5D6A7), // Light Green
      const Color(0xFFF8BBD0), // Light Pink
      const Color(0xFFFFAB91), // Light Deep Orange
    ];

    return isDarkMode ? darkColors[index % darkColors.length] : lightColors[index % lightColors.length];
  }

  Widget _buildCategoryItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDarkMode,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/establishments',
          arguments: {'categoryId': categories.firstWhere((c) => c.name == title).id},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
              Colors.grey.shade800.withOpacity(0.8),
              Colors.grey.shade700.withOpacity(0.8),
            ]
                : [
              Colors.white.withOpacity(0.9),
              Colors.blue.shade50.withOpacity(0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                      iconColor.withOpacity(isDarkMode ? 0.5 : 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.blue.shade800,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withOpacity(0.7),
                      iconColor.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Category {
  final int id;
  final String name;
  final String? slug;

  Category({
    required this.id,
    required this.name,
    this.slug,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
    );
  }
}