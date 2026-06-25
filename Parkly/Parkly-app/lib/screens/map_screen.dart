import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_space.dart';
import '../services/parking_service.dart';
import '../services/language_service.dart';
import 'parking_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ParkingService _parkingService = ParkingService();
  GoogleMapController? _mapController;
  bool _isLocating = false;
  MapType _currentMapType = MapType.normal;
  final lang = LanguageService();

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(45.6427, 25.5887),
    zoom: 13,
  );

  Future<void> _getUserLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (e) {
      debugPrint("Eroare locație: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Set<Marker> _createMarkers(List<ParkingSpace> spaces) {
    return spaces.map((space) {
      String snippet = space.isAvailable
          ? lang.translate('loc_available')
          : lang.translate('loc_occupied');

      double hue = space.availableSpots > 0
          ? BitmapDescriptor.hueGreen
          : BitmapDescriptor.hueRed;

      if (space.isUnderMaintenance) {
        snippet = lang.translate('loc_maintenance');
        hue = BitmapDescriptor.hueOrange;
      }

      return Marker(
        markerId: MarkerId(space.id),
        position: LatLng(space.latitude, space.longitude),
        infoWindow: InfoWindow(
          title: space.name,
          snippet: snippet,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ParkingDetailsScreen(parkingSpace: space)),
            );
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('map_title'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              if (_isLocating)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
            ],
          ),
          body: Stack(
            children: [
              StreamBuilder<List<ParkingSpace>>(
                stream: _parkingService.getParkingSpaces(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Eroare date: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return GoogleMap(
                    initialCameraPosition: _kInitialPosition,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _getUserLocation();
                    },
                    markers: _createMarkers(snapshot.data!),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: _currentMapType,
                  );
                },
              ),
              Positioned(
                left: 15,
                bottom: 20,
                child: _buildMapButton(
                  _currentMapType == MapType.normal
                      ? Icons.satellite_alt
                      : Icons.map_outlined,
                  () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal;
                    });
                  },
                  color: const Color(0xFF2563EB),
                ),
              ),
              Positioned(
                right: 15,
                bottom: 20,
                child: Column(
                  children: [
                    _buildMapButton(
                        Icons.add,
                        () => _mapController
                            ?.animateCamera(CameraUpdate.zoomIn())),
                    const SizedBox(height: 10),
                    _buildMapButton(
                        Icons.remove,
                        () => _mapController
                            ?.animateCamera(CameraUpdate.zoomOut())),
                    const SizedBox(height: 10),
                    _buildMapButton(Icons.my_location, _getUserLocation,
                        color: Colors.blueAccent),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onPressed,
      {Color color = Colors.black87}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }
}
