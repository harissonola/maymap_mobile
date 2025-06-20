import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  List<PlatformFile> _selectedImages = [];

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(result.files.where((file) => file.path != null));
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection des images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection des images: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    final token = await _storage.read(key: 'auth_token');
    if (token == null) throw Exception('Token non disponible');

    final List<String> imageUrls = [];
    final List<Future> uploadFutures = [];

    for (var image in _selectedImages) {
      if (image.path == null) continue;

      uploadFutures.add(() async {
        try {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('http://localhost:8000/api/posts/upload'),
          );
          request.headers['Authorization'] = 'Bearer $token';

          final file = File(image.path!);
          final fileBytes = await file.readAsBytes();

          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              fileBytes,
              filename: image.name,
            ),
          );

          var response = await request.send();
          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonData = json.decode(responseData);
            imageUrls.add(jsonData['url']);
          } else {
            debugPrint('Échec de l\'upload: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Erreur upload image: $e');
        }
      }());
    }

    await Future.wait(uploadFutures);
    return imageUrls;
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final imageUrls = await _uploadImages();
      await _createPost(imageUrls);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPost(List<String> imageUrls) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) throw Exception('Token non disponible');

    final response = await http.post(
      Uri.parse('http://localhost:8000/api/posts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'title': _titleController.text,
        'content': _contentController.text,
        'images': imageUrls,
      }),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 201) {
      Navigator.of(context).pop(responseData['post']);
    } else {
      throw Exception(responseData['error'] ?? response.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Post'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed: _isLoading ? null : _submitPost,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Titre (optionnel)',
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                      TextFormField(
                        controller: _contentController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Contenu',
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          filled: false,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un contenu';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedImages.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Images sélectionnées',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              final image = _selectedImages[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant,
                                        ),
                                        child: Image.file(
                                          File(image.path!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.errorContainer,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            color: theme.colorScheme.onErrorContainer,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: Icon(Icons.image, color: theme.colorScheme.onPrimary),
                label: Text(
                  'Ajouter des images',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}