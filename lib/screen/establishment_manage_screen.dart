import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/animation.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class EstablishmentManageScreen extends StatefulWidget {
  const EstablishmentManageScreen({super.key});

  @override
  State<EstablishmentManageScreen> createState() => _EstablishmentManageScreenState();
}

class _EstablishmentManageScreenState extends State<EstablishmentManageScreen> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  late AnimationController _railAnimationController;

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _telephoneController;

  @override
  void initState() {
    super.initState();
    _railAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _addressController = TextEditingController();
    _telephoneController = TextEditingController();
    _loadEstablishmentData();
  }

  @override
  void dispose() {
    _railAnimationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _loadEstablishmentData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/establishment/manage'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _addressController.text = data['address'] ?? '';
          _telephoneController.text = data['telephone'] ?? '';
          _isLoading = false;
        });
      } else {
        _showError('Échec du chargement des données de l\'établissement');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  Future<void> _saveEstablishmentData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.put(
        Uri.parse('http://localhost:8000/api/establishment/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'address': _addressController.text,
          'telephone': _telephoneController.text,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccess('Informations mises à jour avec succès');
      } else {
        _showError('Échec de la mise à jour des données');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'Erreur',
      desc: message,
      btnOkOnPress: () {},
    ).show();
    setState(() => _isLoading = false);
  }

  void _showSuccess(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      title: 'Succès',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de l\'établissement'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: FadeIn(
          child: const CircularProgressIndicator(),
        ),
      )
          : Row(
        children: [
          ElasticInLeft(
            controller: (controller) => _railAnimationController = controller,
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                  _railAnimationController.reset();
                  _railAnimationController.forward();
                });
              },
              labelType: NavigationRailLabelType.selected,
              backgroundColor: colorScheme.surface.withOpacity(0.9),
              elevation: 4,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.info_outline, color: colorScheme.onSurface),
                  selectedIcon: Icon(Icons.info, color: colorScheme.primary),
                  label: Text('Infos', style: TextStyle(color: colorScheme.onSurface)),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.schedule_outlined, color: colorScheme.onSurface),
                  selectedIcon: Icon(Icons.schedule, color: colorScheme.primary),
                  label: Text('Horaires', style: TextStyle(color: colorScheme.onSurface)),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.photo_library_outlined, color: colorScheme.onSurface),
                  selectedIcon: Icon(Icons.photo_library, color: colorScheme.primary),
                  label: Text('Galerie', style: TextStyle(color: colorScheme.onSurface)),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.article_outlined, color: colorScheme.onSurface),
                  selectedIcon: Icon(Icons.article, color: colorScheme.primary),
                  label: Text('Actualités', style: TextStyle(color: colorScheme.onSurface)),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: FadeInRight(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _EstablishmentInfoTab(
                    formKey: _formKey,
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    addressController: _addressController,
                    telephoneController: _telephoneController,
                    onSave: _saveEstablishmentData,
                    isSaving: _isSaving,
                  ),
                  const _ScheduleTab(),
                  _GalleryTab(),
                  _PostsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstablishmentInfoTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController addressController;
  final TextEditingController telephoneController;
  final VoidCallback onSave;
  final bool isSaving;

  const _EstablishmentInfoTab({
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.addressController,
    required this.telephoneController,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text(
                'Informations générales',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SlideInLeft(
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'établissement',
                  labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            SlideInRight(
              child: TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une description';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            SlideInLeft(
              child: TextFormField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Adresse',
                  labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une adresse';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            SlideInRight(
              child: TextFormField(
                controller: telephoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: TextStyle(color: colorScheme.onSurface),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un numéro de téléphone';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: BounceInUp(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSaving ? null : onSave,
                    child: isSaving
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                        strokeWidth: 3,
                      ),
                    )
                        : Text(
                      'Enregistrer les modifications',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  List<dynamic> _horaires = [];
  String? _selectedDay;
  String? _openingTime;
  String? _closingTime;

  @override
  void initState() {
    super.initState();
    _loadHoraires();
  }

  Future<void> _loadHoraires() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/schedule'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _horaires = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        _showError('Échec du chargement des horaires');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  Future<void> _addHoraire() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDay == null || _openingTime == null || _closingTime == null) {
      _showError('Veuillez remplir tous les champs');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'jour': _selectedDay,
          'heureOuverture': _openingTime,
          'heureFermeture': _closingTime,
        }),
      );

      if (response.statusCode == 201) {
        _showSuccess('Horaire ajouté avec succès');
        _loadHoraires();
        _formKey.currentState!.reset();
        setState(() {
          _selectedDay = null;
          _openingTime = null;
          _closingTime = null;
        });
      } else {
        _showError('Échec de l\'ajout de l\'horaire');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteHoraire(int id) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/schedule/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSuccess('Horaire supprimé avec succès');
        _loadHoraires();
      } else {
        _showError('Échec de la suppression de l\'horaire');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'Erreur',
      desc: message,
      btnOkOnPress: () {},
    ).show();
    setState(() => _isLoading = false);
  }

  void _showSuccess(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      title: 'Succès',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  String _getDayName(int index) {
    switch (index) {
      case 0: return 'Lundi';
      case 1: return 'Mardi';
      case 2: return 'Mercredi';
      case 3: return 'Jeudi';
      case 4: return 'Vendredi';
      case 5: return 'Samedi';
      case 6: return 'Dimanche';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _isLoading
        ? Center(
      child: FadeIn(
        child: CircularProgressIndicator(color: colorScheme.primary),
      ),
    )
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Horaires d\'ouverture',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SlideInUp(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horaires actuels',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_horaires.isEmpty)
                      Text(
                        'Aucun horaire défini',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                      )
                    else
                      ..._horaires.map((horaire) => SlideInLeft(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.onSurface.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(
                              horaire['jour'] ?? 'Jour inconnu',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  horaire['heureOuverture'] != null && horaire['heureFermeture'] != null
                                      ? '${horaire['heureOuverture']} - ${horaire['heureFermeture']}'
                                      : 'Fermé',
                                  style: TextStyle(color: colorScheme.onSurface),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: colorScheme.error),
                                  onPressed: () => _deleteHoraire(horaire['id']),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter un horaire',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Jour',
                                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                  ),
                                  dropdownColor: colorScheme.surface,
                                  style: TextStyle(color: colorScheme.onSurface),
                                  value: _selectedDay,
                                  items: List.generate(7, (index) {
                                    final dayName = _getDayName(index);
                                    return DropdownMenuItem(
                                      value: dayName,
                                      child: Text(dayName),
                                    );
                                  }),
                                  onChanged: (value) {
                                    setState(() => _selectedDay = value);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez sélectionner un jour';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Heure d\'ouverture (HH:MM)',
                                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                  ),
                                  style: TextStyle(color: colorScheme.onSurface),
                                  onChanged: (value) => _openingTime = value,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer une heure';
                                    }
                                    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
                                      return 'Format invalide (HH:MM)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Heure de fermeture (HH:MM)',
                                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                  ),
                                  style: TextStyle(color: colorScheme.onSurface),
                                  onChanged: (value) => _closingTime = value,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer une heure';
                                    }
                                    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
                                      return 'Format invalide (HH:MM)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [colorScheme.primary, colorScheme.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSaving ? null : _addHoraire,
                                child: _isSaving
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.onPrimary,
                                    strokeWidth: 3,
                                  ),
                                )
                                    : Text(
                                  'Ajouter',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTab extends StatefulWidget {
  const _GalleryTab();

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _images = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/establishment/images'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _images = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        _showError('Échec du chargement des images');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _isUploading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:8000/api/upload/image'),
        );

        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: file.name,
          ),
        );

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);

        if (response.statusCode == 201) {
          final createResponse = await http.post(
            Uri.parse('http://localhost:8000/api/establishment/images'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'imageUrl': jsonResponse['imageUrl'],
              'isLogo': false,
            }),
          );

          if (createResponse.statusCode != 201) {
            _showError('Échec de l\'enregistrement des détails pour ${file.name}');
          }
        } else {
          _showError('Échec du téléchargement de ${file.name}');
        }
      }

      _showSuccess('Images ajoutées avec succès');
      _loadImages();
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteImage(int id) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/establishment/images/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSuccess('Image supprimée avec succès');
        _loadImages();
      } else {
        _showError('Échec de la suppression de l\'image');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'Erreur',
      desc: message,
      btnOkOnPress: () {},
    ).show();
    setState(() => _isLoading = false);
  }

  void _showSuccess(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      title: 'Succès',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _isLoading
        ? Center(
      child: FadeIn(
        child: CircularProgressIndicator(color: colorScheme.primary),
      ),
    )
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Galerie photo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_images.isEmpty)
            FadeIn(
              child: Center(
                child: Text(
                  'Aucune image dans la galerie',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            SlideInUp(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return FadeIn(
                    delay: Duration(milliseconds: 100 * index),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.network(
                              'http://localhost:8000/establishments/${image['imageUrl']}',
                              fit: BoxFit.cover,
                              height: double.infinity,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colorScheme.surface,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.white),
                                  onPressed: () => _deleteImage(image['id']),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          FadeInUp(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isUploading ? null : _uploadImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surface,
                        colorScheme.surface.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: _isUploading
                      ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 50,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cliquez pour télécharger des images',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsTab extends StatefulWidget {
  const _PostsTab();

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  List<dynamic> _posts = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/establishment/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _posts = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        _showError('Échec du chargement des actualités');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/establishment/posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': _titleController.text,
          'content': _contentController.text,
        }),
      );

      if (response.statusCode == 201) {
        _showSuccess('Post créé avec succès');
        _titleController.clear();
        _contentController.clear();
        _loadPosts();
      } else {
        _showError('Échec de la création du post');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePost(int id) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/establishment/posts/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSuccess('Post supprimé avec succès');
        _loadPosts();
      } else {
        _showError('Échec de la suppression du post');
      }
    } catch (e) {
      _showError('Erreur de connexion: ${e.toString()}');
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'Erreur',
      desc: message,
      btnOkOnPress: () {},
    ).show();
    setState(() => _isLoading = false);
  }

  void _showSuccess(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      title: 'Succès',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _isLoading
        ? Center(
      child: FadeIn(
        child: CircularProgressIndicator(color: colorScheme.primary),
      ),
    )
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Actualités',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_posts.isEmpty)
            FadeIn(
              child: Center(
                child: Text(
                  'Aucune actualité publiée',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            ..._posts.map(
                  (post) => FadeInUp(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.onSurface.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post['content'],
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Publié le ${post['createdAt']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: colorScheme.primary),
                              onPressed: () {
                                // TODO: Implement post editing
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: colorScheme.error),
                              onPressed: () => _deletePost(post['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FadeInUp(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créer une nouvelle actualité',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre',
                              labelStyle: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.8)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            style: TextStyle(color: colorScheme.onSurface),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un titre';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contentController,
                            decoration: InputDecoration(
                              labelText: 'Contenu',
                              labelStyle: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.8)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            style: TextStyle(color: colorScheme.onSurface),
                            maxLines: 5,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer un contenu';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [colorScheme.primary, colorScheme.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isSaving ? null : _createPost,
                                child: _isSaving
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: colorScheme.onPrimary,
                                    strokeWidth: 3,
                                  ),
                                )
                                    : Text(
                                  'Publier',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }
}