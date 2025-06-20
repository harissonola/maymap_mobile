import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator_linux/geolocator_linux.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:open_route_service/open_route_service.dart' hide GeoPoint;
import 'package:open_route_service/src/models/coordinate_model.dart';

class EstablishmentProfileScreen extends StatefulWidget {
  final String establishmentId;

  const EstablishmentProfileScreen({super.key, required this.establishmentId});

  @override
  State<EstablishmentProfileScreen> createState() => _EstablishmentProfileScreenState();
}

class _EstablishmentProfileScreenState extends State<EstablishmentProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? establishmentData;
  bool isLoading = true;
  String errorMessage = '';
  late TabController _tabController;
  bool _isRouteVisible = false;
  bool _isNavigating = false;
  LatLng? _destination;
  LatLng? _userLocation;
  String _transportMode = 'driving';
  List<Map<String, dynamic>> _routeInstructions = [];
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;
  Position? _currentPosition;
  late FlutterTts _tts;
  StreamSubscription<Position>? _positionStream;
  double _distanceToNextStep = 0.0;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchEstablishmentData();
    _tts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("fr-FR");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionStream?.cancel();
    _navigationTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _fetchEstablishmentData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/profile/establishment/${widget.establishmentId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = json.decode(data['establishment']['location']);
        setState(() {
          establishmentData = data;
          _destination = LatLng(location['latitude'], location['longitude']);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Erreur lors du chargement des données: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Erreur de connexion: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;

    if (Platform.isLinux) {
      _userLocation = await _getFallbackLocation();
      if (_userLocation != null && mounted) {
        await _fetchRoute();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      await _fetchRoute();
    } catch (e) {
      print('Erreur avec Geolocator: $e');

      if (Platform.isLinux) {
        try {
          final response = await http.get(Uri.parse('http://ip-api.com/json'));

          if (!mounted) return;

          final data = json.decode(response.body);

          setState(() {
            _userLocation = LatLng(data['lat'], data['lon']);
          });

          await _fetchRoute();
        } catch (e) {
          print('Erreur avec API de secours: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Impossible d\'obtenir la localisation: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_routeInstructions.isEmpty || _userLocation == null) return;

    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
    });

    // Démarrer le suivi de position
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      _checkProximityToNextStep();
    });

    // Donner la première instruction
    await _speakInstruction(_routeInstructions.first['instruction']);

    // Démarrer le timer pour vérifier régulièrement la position
    _navigationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      _checkProximityToNextStep();
    });
  }

  Future<void> _stopNavigation() async {
    _positionStream?.cancel();
    _navigationTimer?.cancel();
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
    });
  }

  Future<void> _checkProximityToNextStep() async {
    if (_currentPosition == null || _currentStepIndex >= _routeInstructions.length - 1) return;

    final nextStep = _routeInstructions[_currentStepIndex + 1];
    final nextStepPoint = _getPointForInstruction(_currentStepIndex + 1);

    if (nextStepPoint == null) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      nextStepPoint.latitude,
      nextStepPoint.longitude,
    );

    setState(() {
      _distanceToNextStep = distance;
    });

    // Donner des avertissements en fonction de la distance
    if (distance < 100 && _currentStepIndex < _routeInstructions.length - 1) {
      if (distance < 50 && !nextStep['instruction'].contains('arrivé')) {
        await _speakInstruction("Préparez-vous à ${nextStep['instruction'].toLowerCase()}");
      }

      if (distance < 20) {
        await _speakInstruction(nextStep['instruction']);
        setState(() {
          _currentStepIndex++;
        });
      }
    }
  }

  LatLng? _getPointForInstruction(int index) {
    if (index <= 0) return _routePoints.firstOrNull;
    if (index >= _routeInstructions.length - 1) return _routePoints.lastOrNull;

    // Estimation grossière - dans une vraie app, il faudrait mapper les instructions aux points
    final ratio = index / (_routeInstructions.length - 1);
    final pointIndex = min((_routePoints.length * ratio).round(), _routePoints.length - 1);
    return _routePoints[pointIndex];
  }

  Future<void> _speakInstruction(String instruction) async {
    await _tts.speak(instruction);
  }

  Future<void> _fetchRoute() async {
    if (!mounted) return;
    if (_userLocation == null || _destination == null) return;

    // Vérification des coordonnées
    if (_userLocation!.latitude < -90 ||
        _userLocation!.latitude > 90 ||
        _userLocation!.longitude < -180 ||
        _userLocation!.longitude > 180 ||
        _destination!.latitude < -90 ||
        _destination!.latitude > 90 ||
        _destination!.longitude < -180 ||
        _destination!.longitude > 180) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordonnées GPS invalides')),
        );
      }
      return;
    }

    // Vérification du mode de transport
    if (!['driving', 'walking', 'cycling'].contains(_transportMode)) {
      _transportMode = 'driving'; // Valeur par défaut
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$_transportMode/'
            '${_userLocation!.longitude},${_userLocation!.latitude};'
            '${_destination!.longitude},${_destination!.latitude}'
            '?overview=full&geometries=geojson&steps=true&annotations=true',
      );

      print('URL OSRM: $url'); // Pour débogage

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final steps = data['routes'][0]['legs'][0]['steps'];

        // Convertir les points GeoJSON en LatLng
        List<LatLng> routePoints = [];
        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List;
          routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        }

        // Créer les instructions
        List<Map<String, dynamic>> routeInstructions = _createDetailedInstructions(
          steps,
          routePoints,
          _transportMode,
          establishmentData,
        );

        if (!mounted) return;

        setState(() {
          _routePoints = routePoints;
          _routeInstructions = routeInstructions;
          _isRouteVisible = true;
          _isNavigating = false;
        });

        // Afficher le résumé
        final totalDistance = data['routes'][0]['distance']?.toDouble() ?? 0;
        final totalDuration = data['routes'][0]['duration']?.toDouble() ?? 0;
        _showRouteSummary(context, totalDistance, totalDuration);
      } else {
        throw Exception('Erreur OSRM: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erreur de calcul d\'itinéraire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de calcul: ${e.toString()}')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _createDetailedInstructions(List<dynamic> steps, List<LatLng> routePoints, String transportMode, Map<String, dynamic>? establishmentData) {
    List<Map<String, dynamic>> instructions = [];

    // Instruction de départ
    instructions.add({
      'instruction': _getStartInstruction(transportMode),
      'distance': 0.0,
      'duration': 0.0,
      'type': 'depart',
      'icon': 'start'
    });

    double cumulativeDistance = 0;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final maneuver = step['maneuver'];
      final distance = (step['distance'] ?? 0).toDouble();
      final duration = (step['duration'] ?? 0).toDouble();

      cumulativeDistance += distance;

      if (distance < 10 && i < steps.length - 1) continue;

      String instruction = _buildRealisticInstruction(step, maneuver, i, steps.length);
      String instructionType = _getInstructionType(maneuver);
      String iconType = _getIconType(maneuver);

      instructions.add({
        'instruction': instruction,
        'distance': distance,
        'duration': duration,
        'cumulative_distance': cumulativeDistance,
        'type': instructionType,
        'icon': iconType
      });
    }

    // Instruction d'arrivée
    instructions.add({
      'instruction': _getArrivalInstruction(establishmentData),
      'distance': 0.0,
      'duration': 0.0,
      'type': 'arrivee',
      'icon': 'destination'
    });

    return instructions;
  }

  String _buildRealisticInstruction(dynamic step, dynamic maneuver, int stepIndex, int totalSteps) {
    final type = maneuver['type'] ?? '';
    final modifier = maneuver['modifier'] ?? '';
    final streetName = step['name'] ?? '';
    final distance = (step['distance'] ?? 0).toDouble();

    switch (type) {
      case 'depart':
        return _getStartInstruction(_transportMode);

      case 'turn':
        return _getTurnInstruction(modifier, streetName, distance);

      case 'merge':
        return _getMergeInstruction(modifier, streetName);

      case 'on-ramp':
        return 'Prenez la bretelle d\'accès${streetName.isNotEmpty ? ' vers $streetName' : ''}';

      case 'off-ramp':
        return 'Prenez la sortie${streetName.isNotEmpty ? ' vers $streetName' : ''}';

      case 'fork':
        return _getForkInstruction(modifier, streetName);

      case 'roundabout':
        return _getRoundaboutInstruction(step, streetName);

      case 'continue':
        return _getContinueInstruction(streetName, distance);

      case 'arrive':
        return _getArrivalInstruction(establishmentData);

      default:
        return _getDefaultInstruction(streetName, distance);
    }
  }

  String _getTurnInstruction(String modifier, String streetName, double distance) {
    String direction = '';
    switch (modifier) {
      case 'left':
        direction = 'à gauche';
        break;
      case 'right':
        direction = 'à droite';
        break;
      case 'sharp-left':
        direction = 'fortement à gauche';
        break;
      case 'sharp-right':
        direction = 'fortement à droite';
        break;
      case 'slight-left':
        direction = 'légèrement à gauche';
        break;
      case 'slight-right':
        direction = 'légèrement à droite';
        break;
      default:
        direction = modifier;
    }

    if (streetName.isNotEmpty) {
      return 'Tournez $direction sur $streetName dans ${distance > 1000 ? '${(distance/1000).toStringAsFixed(1)} km' : '${distance.toInt()} mètres'}';
    } else {
      return 'Tournez $direction dans ${distance > 1000 ? '${(distance/1000).toStringAsFixed(1)} km' : '${distance.toInt()} mètres'}';
    }
  }

  String _getMergeInstruction(String modifier, String streetName) {
    if (modifier == 'left') {
      return 'Insérez-vous à gauche${streetName.isNotEmpty ? ' sur $streetName' : ''}';
    } else {
      return 'Insérez-vous à droite${streetName.isNotEmpty ? ' sur $streetName' : ''}';
    }
  }

  String _getRoundaboutInstruction(dynamic step, String streetName) {
    final exit = step['maneuver']['exit'] ?? 1;
    String exitText = '';
    switch (exit) {
      case 1:
        exitText = 'la 1ère sortie';
        break;
      case 2:
        exitText = 'la 2ème sortie';
        break;
      case 3:
        exitText = 'la 3ème sortie';
        break;
      default:
        exitText = 'la ${exit}ème sortie';
    }

    return 'Au rond-point, prenez $exitText${streetName.isNotEmpty ? ' vers $streetName' : ''}';
  }

  String _getContinueInstruction(String streetName, double distance) {
    if (streetName.isNotEmpty) {
      if (distance > 1000) {
        return 'Continuez sur $streetName pendant ${(distance/1000).toStringAsFixed(1)} km';
      } else {
        return 'Continuez sur $streetName pendant ${distance.toInt()} mètres';
      }
    } else {
      return 'Continuez tout droit';
    }
  }

  String _getDefaultInstruction(String streetName, double distance) {
    if (streetName.isNotEmpty) {
      return 'Continuez sur $streetName';
    } else if (distance > 500) {
      return 'Continuez tout droit pendant ${(distance/1000).toStringAsFixed(1)} km';
    } else {
      return 'Continuez tout droit pendant ${distance.toInt()} mètres';
    }
  }

  String _getInstructionType(dynamic maneuver) {
    final type = maneuver['type'] ?? '';
    switch (type) {
      case 'turn': return 'turn';
      case 'merge': return 'merge';
      case 'roundabout': return 'roundabout';
      case 'continue': return 'straight';
      default: return 'navigation';
    }
  }

  String _getIconType(dynamic maneuver) {
    final type = maneuver['type'] ?? '';
    final modifier = maneuver['modifier'] ?? '';

    switch (type) {
      case 'turn':
        if (modifier.contains('left')) return 'turn_left';
        if (modifier.contains('right')) return 'turn_right';
        return 'straight';
      case 'roundabout': return 'roundabout';
      case 'merge': return 'merge';
      default: return 'straight';
    }
  }

  String _getDirectionIcon(double bearing) {
    if (bearing >= 315 || bearing < 45) return 'north';
    if (bearing >= 45 && bearing < 135) return 'east';
    if (bearing >= 135 && bearing < 225) return 'south';
    if (bearing >= 225 && bearing < 315) return 'west';
    return 'straight';
  }

  String _getForkInstruction(String modifier, String streetName) {
    if (modifier == 'left') {
      return 'À l\'embranchement, restez à gauche${streetName.isNotEmpty ? ' vers $streetName' : ''}';
    } else {
      return 'À l\'embranchement, restez à droite${streetName.isNotEmpty ? ' vers $streetName' : ''}';
    }
  }

  Future<List<Map<String, dynamic>>> _createSmartInstructions(List<LatLng> routePoints, String transportMode, Map<String, dynamic>? establishmentData) async {
    List<Map<String, dynamic>> instructions = [];

    instructions.add({
      'instruction': _getStartInstruction(transportMode),
      'distance': 0.0,
      'duration': 0.0,
      'type': 'depart',
      'icon': 'start'
    });

    List<LatLng> keyPoints = _extractKeyPoints(routePoints);

    for (int i = 0; i < keyPoints.length - 1; i++) {
      final currentPoint = keyPoints[i];
      final nextPoint = keyPoints[i + 1];

      final bearing = _calculateBearing(currentPoint, nextPoint);
      final distance = Geolocator.distanceBetween(
          currentPoint.latitude, currentPoint.longitude,
          nextPoint.latitude, nextPoint.longitude
      );

      String streetName = await _getStreetName(currentPoint, nextPoint);
      String direction = _getCardinalDirection(bearing);
      String instruction = _buildContextualInstruction(direction, streetName, distance);

      final duration = _calculateDuration(distance, transportMode);

      instructions.add({
        'instruction': instruction,
        'distance': distance,
        'duration': duration,
        'type': 'navigation',
        'icon': _getDirectionIcon(bearing)
      });
    }

    instructions.add({
      'instruction': _getArrivalInstruction(establishmentData),
      'distance': 0.0,
      'duration': 0.0,
      'type': 'arrivee',
      'icon': 'destination'
    });

    return instructions;
  }

  double _calculateDuration(double distanceInMeters, String transportMode) {
    double speedMs;
    switch (transportMode) {
      case 'walking':
        speedMs = 1.4;
        break;
      case 'bicycling':
        speedMs = 4.2;
        break;
      case 'driving':
      default:
        speedMs = 11.1;
        break;
    }

    return distanceInMeters / speedMs;
  }

  String _getStartInstruction(String transportMode) {
    switch (transportMode) {
      case 'walking':
        return 'Commencez à marcher vers votre destination';
      case 'cycling':
        return 'Commencez à rouler vers votre destination';
      case 'driving':
      default:
        return 'Commencez à rouler vers votre destination';
    }
  }

  String _getArrivalInstruction(Map<String, dynamic>? establishmentData) {
    final establishmentName = establishmentData?['establishment']['name'] ?? 'votre destination';
    return 'Vous êtes arrivé à $establishmentName';
  }

  void _showRouteSummary(BuildContext context, double totalDistance, double totalDuration) {
    final distanceText = totalDistance > 1000
        ? '${(totalDistance / 1000).toStringAsFixed(1)} km'
        : '${totalDistance.toInt()} m';

    final hours = (totalDuration / 3600).floor();
    final minutes = ((totalDuration % 3600) / 60).floor();
    String durationText = '';

    if (hours > 0) {
      durationText = '${hours}h ${minutes}min';
    } else {
      durationText = '${minutes}min';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trajet calculé: $distanceText en $durationText'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<LatLng> _extractKeyPoints(List<LatLng> routePoints) {
    if (routePoints.length <= 2) return routePoints;

    List<LatLng> keyPoints = [routePoints.first];

    for (int i = 1; i < routePoints.length - 1; i++) {
      final prev = routePoints[i - 1];
      final current = routePoints[i];
      final next = routePoints[i + 1];

      final bearing1 = _calculateBearing(prev, current);
      final bearing2 = _calculateBearing(current, next);
      final angleDiff = (bearing2 - bearing1).abs();

      final distance = Geolocator.distanceBetween(
          keyPoints.last.latitude, keyPoints.last.longitude,
          current.latitude, current.longitude
      );

      if (angleDiff > 30 || distance > 500) {
        keyPoints.add(current);
      }
    }

    keyPoints.add(routePoints.last);
    return keyPoints;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (3.14159 / 180);
    final startLng = start.longitude * (3.14159 / 180);
    final endLat = end.latitude * (3.14159 / 180);
    final endLng = end.longitude * (3.14159 / 180);

    final dLng = endLng - startLng;
    final y = sin(dLng) * cos(endLat);
    final x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);

    final bearing = atan2(y, x) * (180 / 3.14159);
    return (bearing + 360) % 360;
  }

  String _getCardinalDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'nord';
    if (bearing >= 22.5 && bearing < 67.5) return 'nord-est';
    if (bearing >= 67.5 && bearing < 112.5) return 'est';
    if (bearing >= 112.5 && bearing < 157.5) return 'sud-est';
    if (bearing >= 157.5 && bearing < 202.5) return 'sud';
    if (bearing >= 202.5 && bearing < 247.5) return 'sud-ouest';
    if (bearing >= 247.5 && bearing < 292.5) return 'ouest';
    if (bearing >= 292.5 && bearing < 337.5) return 'nord-ouest';
    return 'tout droit';
  }

  Future<String> _getStreetName(LatLng point1, LatLng point2) async {
    try {
      final midLat = (point1.latitude + point2.latitude) / 2;
      final midLng = (point1.longitude + point2.longitude) / 2;

      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$midLat&lon=$midLng&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'MayMap/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        return address?['road'] ??
            address?['street'] ??
            address?['pedestrian'] ??
            address?['path'] ?? '';
      }
    } catch (e) {
      print('Erreur géocodage inverse: $e');
    }
    return '';
  }

  String _buildContextualInstruction(String direction, String streetName, double distance) {
    if (streetName.isNotEmpty) {
      if (distance > 1000) {
        return 'Continuez vers le $direction sur $streetName pendant ${(distance/1000).toStringAsFixed(1)} km';
      } else {
        return 'Continuez vers le $direction sur $streetName pendant ${distance.toInt()} mètres';
      }
    } else {
      if (distance > 1000) {
        return 'Continuez vers le $direction pendant ${(distance/1000).toStringAsFixed(1)} km';
      } else {
        return 'Continuez vers le $direction pendant ${distance.toInt()} mètres';
      }
    }
  }

  void _showTransportModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisissez votre mode de transport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('En voiture'),
              onTap: () {
                setState(() => _transportMode = 'driving');
                Navigator.pop(context);
                _getUserLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('À pied'),
              onTap: () {
                setState(() => _transportMode = 'walking');
                Navigator.pop(context);
                _getUserLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_bike),
              title: const Text('En vélo'),
              onTap: () {
                setState(() => _transportMode = 'cycling');
                Navigator.pop(context);
                _getUserLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final establishment = establishmentData?['establishment'];
    final logoImage = establishment?['images']?.firstWhere(
          (img) => img['isLogo'] == true,
      orElse: () => {'imageUrl': ''},
    );

    return Stack(
      children: [
        establishment?['images']?.isNotEmpty == true
            ? Image.network(
          'http://localhost:8000/establishments/${establishment['images'][0]['imageUrl']}',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        )
            : Container(
          height: 200,
          color: Colors.grey[300],
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: logoImage['imageUrl'] != null && logoImage['imageUrl'].isNotEmpty
                        ? NetworkImage('http://localhost:8000/establishments/${logoImage['imageUrl']}')
                        : null,
                    child: logoImage['imageUrl'] == null || logoImage['imageUrl'].isEmpty
                        ? const Icon(Icons.business, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          establishment?['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          establishment?['type']['name'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (establishment?['isVerified'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Vérifié',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (establishment?['isVerified'] != true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Non vérifié',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  if (establishment?['isPremium'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (establishment?['isVerified'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Cet établissement n\'est pas vérifié. MayMap s\'en charge pour vous.',
                    style: TextStyle(
                      color: Colors.orange[200],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final ratings = establishmentData?['ratings'] as List? ?? [];
    final avgRating = establishmentData?['average_rating'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      if (index < avgRating.floor()) {
                        return const Icon(Icons.star, color: Colors.amber, size: 20);
                      } else if (index == avgRating.floor() && avgRating % 1 >= 0.5) {
                        return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                      } else {
                        return const Icon(Icons.star_border, color: Colors.amber, size: 20);
                      }
                    }),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${ratings.length} avis',
                    style: const TextStyle(fontSize: 16),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _tabController.animateTo(2);
                    },
                    child: const Text('Voir les avis'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            final starCount = 5 - index;
            final count = ratings.where((r) => r['note'] == starCount).length;
            final percentage = ratings.isNotEmpty ? (count / ratings.length) * 100 : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Text('$starCount étoiles'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    final images = establishmentData?['establishment']['images'] as List? ?? [];

    if (images.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Aucune image disponible')),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GalleryViewer(
                images: images,
                initialIndex: index,
              ),
            ),
          );
        },
        child: Image.network(
          'http://localhost:8000/establishments/${images[index]['imageUrl']}',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final ratings = establishmentData?['ratings'] as List? ?? [];

    if (ratings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Aucun avis pour le moment')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ratings.length,
      itemBuilder: (context, index) {
        final rating = ratings[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: rating['user']['avatar'] != null
                          ? NetworkImage('http://localhost:8000/users/${rating['user']['avatar']}')
                          : null,
                      child: rating['user']['avatar'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating['user']['username'] ?? 'Anonyme',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateTime.parse(rating['createdAt']).toLocal().toString().split(' ')[0],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < rating['note']
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(rating['comment'] ?? ''),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsSection() {
    final posts = establishmentData?['establishment']['posts'] as List? ?? [];

    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Aucun post pour le moment')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final images = post['images'] as List? ?? [];
        final comments = post['comments'] as List? ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: establishmentData?['avatar'] != null
                          ? NetworkImage('http://localhost:8000/users/${establishmentData?['avatar']}')
                          : null,
                      child: establishmentData?['avatar'] == null
                          ? const Icon(Icons.business)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          establishmentData?['establishment']['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateTime.parse(post['createdAt']).toLocal().toString().split(' ')[0],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (post['title'] != null && post['title'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      post['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (post['content'] != null && post['content'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(post['content']),
                  ),

                if (images.isNotEmpty) _buildPostImages(images),

                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${comments.length}'),
                      const SizedBox(width: 16),
                      Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${post['likes']?.length ?? 0}'),
                    ],
                  ),
                ),

                if (comments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < (comments.length > 2 ? 2 : comments.length); i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: comments[i]['user']['avatar'] != null
                                      ? NetworkImage('http://localhost:8000/users/${comments[i]['user']['avatar']}')
                                      : null,
                                  child: comments[i]['user']['avatar'] == null
                                      ? const Icon(Icons.person, size: 12)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comments[i]['user']['username'] ?? 'Anonyme',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        comments[i]['content'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (comments.length > 2)
                          Text(
                            'Voir les ${comments.length - 2} commentaires supplémentaires',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostImages(List<dynamic> images) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            'http://localhost:8000/posts/${images[0]['imageUrl']}',
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (images.length == 2) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'http://localhost:8000/posts/${images[0]['imageUrl']}',
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'http://localhost:8000/establishments/${images[1]['imageUrl']}',
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'http://localhost:8000/posts/${images[0]['imageUrl']}',
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: images.length - 1 > 3 ? 3 : images.length - 1,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'http://localhost:8000/posts/${images[index + 1]['imageUrl']}',
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          if (images.length - 1 > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '+ ${images.length - 4} autres images',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    if (_userLocation == null || _destination == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _userLocation!,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                  ),
                  Marker(
                    point: _destination!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (_isNavigating)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Prochaine étape dans ${_distanceToNextStep.toInt()} mètres',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _distanceToNextStep > 0 && (_routeInstructions[_currentStepIndex]['distance'] as num).toDouble() > 0
                      ? _distanceToNextStep / (_routeInstructions[_currentStepIndex]['distance'] as num).toDouble()
                      : 0,
                  backgroundColor: Colors.grey[200],
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4, // 40% de la hauteur de l'écran
          child: _routeInstructions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _routeInstructions.length,
            itemBuilder: (context, index) {
              final step = _routeInstructions[index];
              final distance = (step['distance'] as num).toDouble();
              final duration = (step['duration'] as num).toDouble();

              String timeText = '';
              if (duration > 0) {
                if (duration < 60) {
                  timeText = '${duration.toInt()} sec';
                } else {
                  final minutes = (duration / 60).toInt();
                  final seconds = (duration % 60).toInt();
                  if (seconds > 0) {
                    timeText = '${minutes} min ${seconds} sec';
                  } else {
                    timeText = '${minutes} min';
                  }
                }
              } else {
                timeText = '0 sec';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  leading: Icon(
                    _getStepIcon(step['instruction']),
                    color: _currentStepIndex == index ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    step['instruction'],
                    style: TextStyle(
                      fontWeight: _currentStepIndex == index ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: distance > 0
                      ? Text('${distance.toStringAsFixed(0)} m • $timeText')
                      : Text(timeText),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isNavigating
              ? ElevatedButton(
            onPressed: _stopNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Arrêter la navigation', style: TextStyle(color: Colors.white)),
          )
              : ElevatedButton(
            onPressed: _startNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Démarrer la navigation', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  IconData _getStepIcon(String instruction) {
    if (instruction.toLowerCase().contains('tournez à gauche')) return Icons.turn_left;
    if (instruction.toLowerCase().contains('tournez à droite')) return Icons.turn_right;
    if (instruction.toLowerCase().contains('continuez tout droit')) return Icons.straight;
    if (instruction.toLowerCase().contains('départ')) return Icons.flag;
    if (instruction.toLowerCase().contains('arrivée')) return Icons.flag_circle;
    return Icons.directions;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Établissement')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Établissement')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchEstablishmentData,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Établissement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            onPressed: _showTransportModeDialog,
          ),
        ],
      ),
      body: _isRouteVisible
          ? _buildRouteSection()
          : DefaultTabController(
        length: 4,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverToBoxAdapter(child: _buildRatingSection()),
            SliverAppBar(
              pinned: true,
              floating: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 48,
              collapsedHeight: 48,
              expandedHeight: 48,
              flexibleSpace: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Galerie'),
                      Tab(text: 'Infos'),
                      Tab(text: 'Avis'),
                      Tab(text: 'Posts'),
                    ],
                  ),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildGallerySection(),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(establishmentData?['establishment']['description'] ?? ''),
                          const SizedBox(height: 16),
                          const Text(
                            'Horaires',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...(establishmentData?['establishment']['horaires'] as List? ?? []).map((horaire) {
                            final opening = DateTime.parse(horaire['heureOuverture']).toLocal();
                            final closing = DateTime.parse(horaire['heureFermeture']).toLocal();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Text(horaire['jour']),
                                  const Spacer(),
                                  Text('${opening.hour}:${opening.minute.toString().padLeft(2, '0')} - ${closing.hour}:${closing.minute.toString().padLeft(2, '0')}'),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                          if (establishmentData?['establishment']['telephone'] != null) ...[
                            const Text(
                              'Contact',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone),
                                const SizedBox(width: 8),
                                Text(establishmentData?['establishment']['telephone'] ?? ''),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (establishmentData?['establishment']['address'] != null) ...[
                            const Text(
                              'Adresse',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(establishmentData?['establishment']['address'] ?? ''),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildReviewsSection(),
              _buildPostsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: _isRouteVisible
          ? FloatingActionButton(
        onPressed: () {
          if (_isNavigating) {
            _stopNavigation();
          }
          setState(() => _isRouteVisible = false);
        },
        child: const Icon(Icons.close),
      )
          : null,
    );
  }
}

class GalleryViewer extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const GalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} sur ${widget.images.length}'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  'http://localhost:8000/establishments/${widget.images[index]['imageUrl']}',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

Future<LatLng?> _getFallbackLocation() async {
  try {
    final response = await http.get(Uri.parse('http://ip-api.com/json'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LatLng(data['lat'], data['lon']);
    }
  } catch (e) {
    print('Erreur avec l\'API de secours: $e');
  }
  return null;
}