import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maymap_mobile/screen/categories.dart';
import 'package:maymap_mobile/screen/create_post_screen.dart';
import 'package:maymap_mobile/screen/establishment_manage_screen.dart';
import 'package:maymap_mobile/screen/establishment_post_profile_screen.dart';
import 'package:maymap_mobile/screen/favorite.dart';
import 'package:maymap_mobile/screen/home.dart' hide Navigator;
import 'package:maymap_mobile/screen/login.dart';
import 'package:maymap_mobile/screen/messages.dart';
import 'package:maymap_mobile/screen/profile_screen.dart';
import 'package:maymap_mobile/screen/registration_screen.dart';
import 'package:maymap_mobile/screen/user_profile_screen.dart';
import 'package:maymap_mobile/services/language_service.dart';
import 'package:maymap_mobile/widgets/language_selector.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:maymap_mobile/screen/search_result_screen.dart';

// Variable globale pour gérer l'état du thème
ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: LanguageService.getLocalLanguage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ValueListenableBuilder<bool>(
            valueListenable: isDarkMode,
            builder: (context, darkMode, child) {
              return MaterialApp(
                title: 'MayMap',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.deepPurple,
                    brightness: Brightness.light,
                  ),
                  useMaterial3: true,
                  appBarTheme: const AppBarTheme(
                    elevation: 0,
                    centerTitle: false,
                    scrolledUnderElevation: 4,
                  ),
                ),
                darkTheme: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: Colors.deepPurple[300]!,
                    secondary: Colors.tealAccent[200]!,
                  ),
                  appBarTheme: const AppBarTheme(
                    elevation: 0,
                    centerTitle: false,
                    scrolledUnderElevation: 4,
                  ),
                ),
                themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
                initialRoute: '/',
                routes: {
                  '/': (context) {
                    return FutureBuilder(
                      future: const FlutterSecureStorage().read(key: 'auth_token'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return const MainNavigation();
                        }
                        return Scaffold(
                          body: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                darkMode ? Colors.deepPurple[300]! : Colors.deepPurple,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegistrationScreen(),
                  '/categories': (context) => const CategoriesScreen(),
                  '/home': (context) => const MainNavigation(),
                  '/profile': (context) => const ProfileScreen(),
                  '/establishment/manage': (context) => const EstablishmentManageScreen(),
                  '/create-post': (context) => const CreatePostScreen(),
                  '/establishmentProfile': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
                    final establishmentId = args?['establishmentId'] ?? '';
                    return EstablishmentProfileScreen(establishmentId: establishmentId);
                  },
                  '/userProfile': (context) {
                    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
                    final userId = args?['userId'] ?? '';
                    return UserProfileScreen(userId: userId);
                  },
                },
              );
            },
          );
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _currentLanguage = 'fr';
  bool _isLoggedIn = false;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;
  late AnimationController _floatingButtonController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  final List<Widget> _pages = [
    const HomePage(),
    const FavoritesScreen(),
    const CategoriesScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
    _checkLoginStatus();

    _animationControllers = List.generate(
      _pages.length,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );

    _animations = List.generate(
      _pages.length,
          (index) => Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: _animationControllers[index],
          curve: Curves.easeInOut,
        ),
      ),
    );

    _floatingButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animationControllers[_selectedIndex].forward();
    _floatingButtonController.forward();

    // Supprimez ou modifiez cet écouteur pour qu'il ne déclenche pas la recherche
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
          _showSearchResults = false;
        });
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    _floatingButtonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/search?q=$query'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultScreen(
              query: query,
              results: data['results'] ?? [],
              isLoading: false,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultScreen(
              query: query,
              results: [],
              isLoading: false,
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultScreen(
            query: query,
            results: [],
            isLoading: false,
          ),
        ),
      );
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Erreur',
          desc: 'Une erreur est survenue: ${e.toString()}',
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Widget _buildSearchResults() {
    if (!_showSearchResults) return const SizedBox.shrink();

    return Positioned(
      top: 150,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Aucun résultat trouvé'),
              )
            else
              ..._searchResults.map((result) => ListTile(
                leading: result['imageUrl'] != null
                    ? CircleAvatar(
                  backgroundImage: NetworkImage(result['imageUrl']),
                )
                    : const CircleAvatar(
                  child: Icon(Icons.place),
                ),
                title: Text(result['name'] ?? ''),
                subtitle: Text(result['address'] ?? ''),
                trailing: result['distance'] != null
                    ? Text('${result['distance']} km')
                    : null,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/establishmentProfile',
                    arguments: {'establishmentId': result['id'].toString()},
                  );
                },
              )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    final token = await _storage.read(key: 'auth_token');
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  Future<void> _loadCurrentLanguage() async {
    final language = await LanguageService.getLocalLanguage();
    setState(() {
      _currentLanguage = language;
    });
  }

  void _showNotifications() {
    final List<Map<String, dynamic>> notifications = [
      {
        'id': 1,
        'icon': Icons.favorite,
        'iconColor': Colors.red,
        'title': "Nouveau like",
        'message': "Votre publication 'Café du Centre' a reçu 12 likes",
        'time': "2 min",
        'isUnread': true,
      },
      {
        'id': 2,
        'icon': Icons.comment,
        'iconColor': Colors.blue,
        'title': "Nouveau commentaire",
        'message': "Jean a commenté votre publication",
        'time': "1h",
        'isUnread': true,
      },
      {
        'id': 3,
        'icon': Icons.people,
        'iconColor': Colors.green,
        'title': "Nouveau follower",
        'message': "Marie suit maintenant votre compte",
        'time': "3h",
        'isUnread': false,
      },
      {
        'id': 4,
        'icon': Icons.star,
        'iconColor': Colors.amber,
        'title': "Nouvelle recommandation",
        'message': "Votre établissement a été recommandé par un utilisateur",
        'time': "5h",
        'isUnread': false,
      },
      {
        'id': 5,
        'icon': Icons.update,
        'iconColor': Colors.purple,
        'title': "Mise à jour disponible",
        'message': "Une nouvelle version de l'application est disponible",
        'time': "1j",
        'isUnread': false,
      },
    ];

    ValueNotifier<List<Map<String, dynamic>>> notificationsNotifier =
    ValueNotifier<List<Map<String, dynamic>>>(notifications);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: notificationsNotifier,
          builder: (context, notifs, _) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            Tooltip(
                              message: 'Marquer toutes comme lues',
                              child: IconButton(
                                icon: Icon(
                                  Icons.check_circle_outline,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: () {
                                  final updated = notifs.map((n) =>
                                  {...n, 'isUnread': false}).toList();
                                  notificationsNotifier.value = updated;

                                  AwesomeDialog(
                                    context: context,
                                    dialogType: DialogType.success,
                                    animType: AnimType.bottomSlide,
                                    title: 'Succès',
                                    desc: 'Toutes les notifications ont été marquées comme lues',
                                    btnOkOnPress: () {},
                                  ).show();
                                },
                              ),
                            ),
                            Tooltip(
                              message: 'Fermer',
                              child: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: theme.colorScheme.onSurface,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off,
                            size: 60,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification',
                            style: TextStyle(
                              fontSize: 18,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: notifs.length,
                      itemBuilder: (context, index) {
                        final notification = notifs[index];
                        return _buildNotificationItem(
                          id: notification['id'],
                          icon: notification['icon'],
                          iconColor: notification['iconColor'],
                          title: notification['title'],
                          message: notification['message'],
                          time: notification['time'],
                          isUnread: notification['isUnread'],
                          onDismiss: (id) {
                            notificationsNotifier.value =
                                notifs.where((n) => n['id'] != id).toList();
                          },
                          onTap: (id) {
                            final updated = notifs.map((n) =>
                            n['id'] == id ? {...n, 'isUnread': false} : n).toList();
                            notificationsNotifier.value = updated;
                          },
                        );
                      },
                    ),
                  ),
                  if (notifs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Tooltip(
                        message: 'Supprimer toutes les notifications',
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.question,
                              animType: AnimType.bottomSlide,
                              title: 'Confirmation',
                              desc: 'Voulez-vous vraiment supprimer toutes les notifications ?',
                              btnCancelOnPress: () {},
                              btnOkText: 'Supprimer',
                              btnOkColor: Colors.red,
                              btnOkOnPress: () {
                                notificationsNotifier.value = [];
                              },
                            ).show();
                          },
                          child: const Text('Effacer toutes les notifications'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required int id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    required bool isUnread,
    required Function(int) onDismiss,
    required Function(int) onTap,
  }) {
    return Dismissible(
      key: Key('notif_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await AwesomeDialog(
          context: context,
          dialogType: DialogType.warning,
          animType: AnimType.bottomSlide,
          title: 'Supprimer',
          desc: 'Voulez-vous supprimer cette notification ?',
          btnCancelOnPress: () {},
          btnOkOnPress: () => true,
        ).show().then((value) => value ?? false);
      },
      onDismissed: (_) => onDismiss(id),
      child: InkWell(
        onTap: () => onTap(id),
        child: ListTile(
          leading: Tooltip(
            message: 'Type de notification',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (isUnread)
                Tooltip(
                  message: 'Non lue',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: message,
                child: Text(
                  message,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          trailing: Tooltip(
            message: 'Options',
            child: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelector(
        currentLanguage: _currentLanguage,
        onLanguageChanged: (newLanguage) {
          setState(() {
            _currentLanguage = newLanguage;
          });
        },
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      if (_isLoggedIn)
                        _buildUserSection(),
                      _buildMenuSection(
                        title: 'Préférences',
                        items: [
                          _buildMenuItem(
                            icon: isDarkMode.value ? Icons.light_mode : Icons.dark_mode,
                            title: isDarkMode.value ? 'Mode clair' : 'Mode sombre',
                            onTap: () {
                              isDarkMode.value = !isDarkMode.value;
                              Navigator.of(context).pop();
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.language,
                            title: 'Langue',
                            subtitle: _currentLanguage == 'fr' ? 'Français' : 'Anglais',
                            onTap: _showLanguageSelector,
                          ),
                        ],
                      ),
                      _buildMenuSection(
                        title: 'Application',
                        items: [
                          _buildMenuItem(
                            icon: Icons.info_outline,
                            title: 'À propos',
                            onTap: () {
                              Navigator.of(context).pop();
                              _showAboutDialog();
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.star_border,
                            title: 'Noter l\'app',
                            onTap: () {},
                          ),
                          _buildMenuItem(
                            icon: Icons.share,
                            title: 'Partager',
                            onTap: () {},
                          ),
                        ],
                      ),
                      _buildMenuSection(
                        title: 'Compte',
                        items: [
                          if (_isLoggedIn)
                            _buildMenuItem(
                              icon: Icons.logout,
                              title: 'Déconnexion',
                              color: Colors.red,
                              onTap: () async {
                                await _storage.delete(key: 'auth_token');
                                await _storage.delete(key: 'user_data');
                                setState(() {
                                  _isLoggedIn = false;
                                });
                                Navigator.of(context).pop();
                                Navigator.of(context).pushReplacementNamed('/login');
                              },
                            )
                          else
                            _buildMenuItem(
                              icon: Icons.login,
                              title: 'Connexion/Inscription',
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pushNamed('/login');
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'MayMap v1.0.0',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utilisateur connecté',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voir votre profil',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: items,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (color ?? theme.colorScheme.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color ?? theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'À propos de MayMap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MayMap est une application de découverte et de navigation urbaine.\n\n'
                    'Version 1.0.0\n'
                    '© 2025 MayMap Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _animations[index],
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : theme.iconTheme.color?.withOpacity(0.8),
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CAF50),
                    Colors.tealAccent.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'MayMap',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              smallSize: 8,
              backgroundColor: theme.colorScheme.secondary,
              child: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: Icon(
              Icons.language,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            onPressed: _showLanguageSelector,
          ),
          IconButton(
            icon: Icon(
              Icons.menu,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            onPressed: _showMenu,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[800]?.withOpacity(0.8)
                    : Colors.grey[100]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Recherche...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _showSearchResults = false;
                            });
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _performSearch(_searchController.text);
                        },
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onSubmitted: (value) {
                  _performSearch(value);
                },
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _pages[_selectedIndex],
          _buildSearchResults(),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _floatingButtonController,
        child: FloatingActionButton(
          onPressed: () {
            if (_isLoggedIn) {
              Navigator.of(context).pushNamed('/create-post');
            } else {
              Navigator.of(context).pushNamed('/login');
            }
          },
          backgroundColor: theme.colorScheme.primary,
          elevation: 6,
          child: Icon(
            Icons.add,
            color: theme.colorScheme.onPrimary,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            height: 70,
            padding: EdgeInsets.zero,
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(0, Icons.home_outlined, 'Accueil'),
                _buildBottomNavItem(1, Icons.favorite_outline, 'Favoris'),
                _buildBottomNavItem(2, Icons.grid_view, 'Catégories'),
                const SizedBox(width: 40),
                _buildBottomNavItem(3, Icons.message_outlined, 'Messages'),
                _buildBottomNavItem(4, Icons.person_outline, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _animationControllers[_selectedIndex].reverse();
          _selectedIndex = index;
          _animationControllers[_selectedIndex].forward();
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedIcon(index, icon),
          AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}