import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  // ignore: unused_field
  GoogleMapController? _mapController;

  static const LatLng _brasovCenter = LatLng(45.6427, 25.5887);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Parking Status'),
        elevation: 2,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('parking_spaces').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final Set<Marker> markers = _buildMarkers(snapshot.data!.docs);

              return GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _brasovCenter,
                  zoom: 13,
                ),
                markers: markers,
                onMapCreated: (controller) => _mapController = controller,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              );
            },
          ),

          // Legendă poziționată deasupra hărții
          Positioned(
            top: 10,
            left: 10,
            child: _buildFloatingLegend(),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(List<QueryDocumentSnapshot> docs) {
    final Set<Marker> markers = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final LatLng? pos = _getLatLng(data);

      if (pos == null) continue;

      final bool isMaintenance = data['isUnderMaintenance'] ?? false;
      final int available = (data['availableSpots'] as num? ?? 0).toInt();

      double hue;
      String colorKey;
      String statusStr;

      if (isMaintenance) {
        hue = BitmapDescriptor.hueOrange;
        colorKey = 'orange';
        statusStr = 'UNAVAILABLE';
      } else if (available > 0) {
        hue = BitmapDescriptor.hueGreen;
        colorKey = 'green';
        statusStr = 'AVAILABLE';
      } else {
        hue = BitmapDescriptor.hueRed;
        colorKey = 'red';
        statusStr = 'FULL';
      }

      markers.add(
        Marker(
          markerId: MarkerId('${doc.id}_$colorKey'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: data['name'] ?? 'Parking Spot',
            snippet: 'Status: $statusStr | Locuri: $available',
          ),
        ),
      );
    }
    return markers;
  }

  LatLng? _getLatLng(Map<String, dynamic> data) {
    // 1. Verificăm formatul GeoPoint (standard Firebase)
    if (data['location'] is GeoPoint) {
      final GeoPoint geo = data['location'];
      return LatLng(geo.latitude, geo.longitude);
    }

    // 2. Verificăm câmpuri separate (lat/lng sau latitude/longitude)
    final num? lat = data['lat'] ?? data['latitude'];
    final num? lng = data['lng'] ?? data['longitude'];

    if (lat != null && lng != null) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }

    return null;
  }

  Widget _buildFloatingLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem(Colors.green, "Available"),
          const SizedBox(height: 4),
          _buildLegendItem(Colors.red, "Full"),
          const SizedBox(height: 4),
          _buildLegendItem(Colors.orange, "Unavailable"),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}