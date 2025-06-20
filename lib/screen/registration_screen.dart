import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _storage = const FlutterSecureStorage();
  bool? _isEstablishment;
  bool _showUserTypeSelection = true;
  List<Map<String, dynamic>> _establishmentTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchEstablishmentTypes();
  }

  Future<void> _fetchEstablishmentTypes() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/api/establishment/types'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _establishmentTypes = data.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching establishment types: $e");
      }
    }
  }

  void _selectUserType(bool isEstablishment) {
    setState(() {
      _isEstablishment = isEstablishment;
      _showUserTypeSelection = false;
    });
  }

  void _goBackToSelection() {
    setState(() {
      _isEstablishment = null;
      _showUserTypeSelection = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
        leading: _showUserTypeSelection
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToSelection,
        ),
      ),
      body: _showUserTypeSelection
          ? _buildUserTypeSelection()
          : RegistrationForm(
        isEstablishment: _isEstablishment!,
        onBack: _goBackToSelection,
        establishmentTypes: _establishmentTypes,
      ),
    );
  }

  Widget _buildUserTypeSelection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _UserTypeCard(
                        icon: Icons.person,
                        title: 'Client',
                        description:
                        'Créez un compte pour découvrir les meilleurs établissements et laisser des avis.',
                        onTap: () => _selectUserType(false),
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _UserTypeCard(
                        icon: Icons.store,
                        title: 'Établissement',
                        description:
                        'Créez un compte pour votre établissement et augmentez votre visibilité.',
                        onTap: () => _selectUserType(true),
                        color: Colors.blue,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Choisissez votre type de compte',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    _UserTypeCard(
                      icon: Icons.person,
                      title: 'Client',
                      description:
                      'Créez un compte pour découvrir les meilleurs établissements et laisser des avis.',
                      onTap: () => _selectUserType(false),
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 20),
                    _UserTypeCard(
                      icon: Icons.store,
                      title: 'Établissement',
                      description:
                      'Créez un compte pour votre établissement et augmentez votre visibilité.',
                      onTap: () => _selectUserType(true),
                      color: Colors.blue,
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color color;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon, size: 60, color: Colors.white),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: onTap,
                  child: const Text('Choisir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrationForm extends StatefulWidget {
  final bool isEstablishment;
  final VoidCallback onBack;
  final List<Map<String, dynamic>> establishmentTypes;

  const RegistrationForm({
    super.key,
    required this.isEstablishment,
    required this.onBack,
    required this.establishmentTypes,
  });

  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  int _currentStep = 0;

  // User fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fnameController = TextEditingController();
  final TextEditingController _lnameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  // Establishment fields
  final TextEditingController _establishmentNameController =
  TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Map<String, dynamic>? _location;
  List<PlatformFile> _selectedImages = [];
  bool _isLocationSelected = false;
  String? _selectedTypeId;

  bool _isLoading = false;
  String? _errorMessage;

  // Flutter Map
  final MapController _mapController = MapController();
  LatLng _currentMapPosition = const LatLng(46.603, 1.888); // Centré sur la France

  @override
  void dispose() {
    _emailController.dispose();
    _fnameController.dispose();
    _lnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _establishmentNameController.dispose();
    _addressController.dispose();
    _telephoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null) {
        setState(() {
          _selectedImages.addAll(result.files);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error picking files: $e");
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            _location = {
              'latitude': data['lat'],
              'longitude': data['lon'],
            };
            _currentMapPosition = LatLng(data['lat'], data['lon']);
            _isLocationSelected = true;
          });

          _mapController.move(_currentMapPosition, 15.0);

          // Mettre à jour l'adresse si disponible
          if (data['city'] != null && data['country'] != null) {
            String address = '${data['city']}, ${data['country']}';
            if (data['regionName'] != null) {
              address = '${data['city']}, ${data['regionName']}, ${data['country']}';
            }
            _addressController.text = address;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${data['message'] ?? 'Impossible de déterminer la localisation'}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la récupération de la localisation')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting location: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de connexion lors de la récupération de la localisation')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = widget.isEstablishment
          ? 'http://localhost:8000/api/register/establishment'
          : 'http://localhost:8000/api/register/client';

      final Map<String, dynamic> requestData = {
        'email': _emailController.text,
        'fname': _fnameController.text,
        'lname': _lnameController.text,
        'username': _usernameController.text,
        'plainPassword': _passwordController.text,
      };

      if (widget.isEstablishment) {
        List<Map<String, dynamic>> images = [];
        for (var file in _selectedImages) {
          final bytes = await File(file.path!).readAsBytes();
          images.add({
            'base64': base64Encode(bytes),
            'extension': file.extension,
          });
        }

        requestData.addAll({
          'establishmentName': _establishmentNameController.text,
          'address': _addressController.text,
          'telephone': _telephoneController.text,
          'description': _descriptionController.text,
          'location': _location,
          'type': _selectedTypeId,
          'images': images,
        });
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      final responseData = jsonDecode(response.body);
      if (kDebugMode) {
        print(responseData);
      }

      if (response.statusCode == 201) {
        if (widget.isEstablishment) {
          await _storage.write(
              key: 'auth_token', value: responseData['token'] ?? '');
          await _storage.write(
              key: 'user_id', value: responseData['user']['id'].toString());
          await _storage.write(
              key: 'establishment_id',
              value: responseData['establishment']['id'].toString());
        } else {
          await _storage.write(
              key: 'auth_token', value: responseData['token'] ?? '');
          await _storage.write(
              key: 'user_id', value: responseData['user']['id'].toString());
        }

        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Erreur lors de l\'inscription';
          if (responseData['errors'] != null) {
            _errorMessage = 'Veuillez corriger les erreurs dans le formulaire';
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion. Veuillez réessayer.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Informations personnelles'),
        content: _buildPersonalInfoStep(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      if (widget.isEstablishment)
        Step(
          title: const Text('Informations établissement'),
          content: _buildEstablishmentInfoStep(),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        ),
      if (widget.isEstablishment)
        Step(
          title: const Text('Localisation'),
          content: _buildLocationStep(),
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        ),
      if (widget.isEstablishment)
        Step(
          title: const Text('Images'),
          content: _buildImagesStep(),
          isActive: _currentStep >= 3,
          state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        ),
      Step(
        title: const Text('Confirmation'),
        content: _buildConfirmationStep(),
        isActive: _currentStep >= (widget.isEstablishment ? 4 : 1),
        state: _currentStep > (widget.isEstablishment ? 4 : 1)
            ? StepState.complete
            : StepState.indexed,
      ),
    ];
  }

  Widget _buildPersonalInfoStep() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Veuillez entrer un email valide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fnameController,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre prénom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lnameController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'utilisateur',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un nom d\'utilisateur';
                }
                if (value.length < 3) {
                  return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un mot de passe';
                }
                if (value.length < 6) {
                  return 'Le mot de passe doit contenir au moins 6 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentInfoStep() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _establishmentNameController,
            decoration: const InputDecoration(
              labelText: 'Nom de l\'établissement',
              prefixIcon: Icon(Icons.store),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer le nom de votre établissement';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer l\'adresse de votre établissement';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Type d\'établissement',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            value: _selectedTypeId,
            items: widget.establishmentTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['id'],
                child: Text(type['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTypeId = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez sélectionner un type d\'établissement';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telephoneController,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un numéro de téléphone';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer une description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMapPosition,
              initialZoom: 6.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _location = {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                  };
                  _currentMapPosition = point;
                  _isLocationSelected = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_isLocationSelected)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentMapPosition,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _getCurrentLocation,
          icon: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Icon(Icons.my_location),
          label: const Text('Utiliser ma position actuelle'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tapez sur la carte pour sélectionner une position',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        if (_isLocationSelected)
          const Text(
            'Localisation définie',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  Widget _buildImagesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Ajouter des images'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedImages.isEmpty)
          const Center(
            child: Text(
              'Aucune image sélectionnée',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImages[index].path!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'LOGO PRINCIPAL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vérifiez vos informations avant de soumettre:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Informations personnelles:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Email: ${_emailController.text}'),
          Text('Prénom: ${_fnameController.text}'),
          Text('Nom: ${_lnameController.text}'),
          Text('Nom d\'utilisateur: ${_usernameController.text}'),
          if (widget.isEstablishment) ...[
            const SizedBox(height: 20),
            const Text(
              'Informations de l\'établissement:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Nom: ${_establishmentNameController.text}'),
            Text('Adresse: ${_addressController.text}'),
            Text('Téléphone: ${_telephoneController.text}'),
            Text('Description: ${_descriptionController.text}'),
            if (_selectedTypeId != null)
              Text('Type: ${widget.establishmentTypes.firstWhere((type) => type['id'] == _selectedTypeId)['name']}'),
            if (_location != null)
              Text(
                  'Localisation: ${_location!['latitude']}, ${_location!['longitude']}'),
            const SizedBox(height: 10),
            const Text(
              'Images:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_selectedImages.isEmpty)
              const Text('Aucune image sélectionnée')
            else
              Text('${_selectedImages.length} image(s) sélectionnée(s)'),
          ],
          const SizedBox(height: 20),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
        ),
      ),
      child: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < _buildSteps().length - 1) {
            if (_validateCurrentStep()) {
              setState(() {
                _currentStep += 1;
              });
            }
          } else {
            _register();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            widget.onBack();
          }
        },
        steps: _buildSteps(),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep != 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Retour'),
                  )
                else
                  OutlinedButton(
                    onPressed: widget.onBack,
                    child: const Text('Retour'),
                  ),
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(_currentStep == _buildSteps().length - 1
                      ? 'Soumettre'
                      : 'Continuer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      return _formKey.currentState!.validate();
    } else if (widget.isEstablishment && _currentStep == 1 && _selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un type d\'établissement')),
      );
      return false;
    } else if (widget.isEstablishment && _currentStep == 2 && !_isLocationSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une localisation')),
      );
      return false;
    }
    return true;
  }
}