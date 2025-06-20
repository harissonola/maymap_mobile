import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerifyAccountScreen extends StatefulWidget {
  final String email;

  const VerifyAccountScreen({super.key, required this.email});

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _isResending = false;
  bool _verificationSuccess = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/verify/account'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'code': _codeController.text.trim(),
        }),
      );

      final responseData = json.decode(response.body);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        setState(() => _verificationSuccess = true);
        _showSuccessSnackBar('Compte vérifié avec succès!');

        // Rediriger vers l'écran de connexion après un délai
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamed(context, '/login');
          }
        });
      } else {
        _showErrorSnackBar(responseData['error'] ?? 'Erreur de vérification');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('Erreur de connexion au serveur');
    }
  }

  Future<void> _resendVerificationCode() async {
    setState(() => _isResending = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/verify/resend-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
        }),
      );

      final responseData = json.decode(response.body);
      if (!mounted) return;

      setState(() => _isResending = false);

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Nouveau code envoyé à ${widget.email}');
      } else {
        _showErrorSnackBar(responseData['error'] ?? 'Erreur lors de l\'envoi du code');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showErrorSnackBar('Erreur de connexion au serveur');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification du compte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.verified_user,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Vérification du compte',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Un code de vérification a été envoyé à',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 30),
            if (!_verificationSuccess)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Code de vérification',
                        prefixIcon: const Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer le code de vérification';
                        }
                        if (!RegExp(r'^MayMap-\d{4}$').hasMatch(value)) {
                          return 'Format du code invalide (ex: MayMap-1234)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAccount,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Vérifier le compte',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: _isResending ? null : _resendVerificationCode,
                      child: _isResending
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('Renvoyer le code'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Votre compte a été vérifié avec succès!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour à la connexion'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}