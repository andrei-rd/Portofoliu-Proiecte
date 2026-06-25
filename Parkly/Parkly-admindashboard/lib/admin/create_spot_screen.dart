import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class CreateSpotScreen extends StatefulWidget {
  const CreateSpotScreen({super.key});

  @override
  State<CreateSpotScreen> createState() => _CreateSpotScreenState();
}

class _CreateSpotScreenState extends State<CreateSpotScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(45.6427, 25.5887); // Default Brasov
  bool _isFetchingAddress = false;
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _spotNumberController = TextEditingController();
  final _imageController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isUnderMaintenance = false;
  bool _isAlwaysAvailable = false;
  bool _isManuallyDisabled = false;
  List<String> _imageUrls = [];
  List<String> _selectedFacilities = [];
  final String _apiKey = "AIzaSyBaCn_LG8dCxqG6k-dixYdLfuJ8d4Gn83Y";

  final Map<String, String> _availableFacilities = {
    'videocam': 'Supraveghere Video',
    'lighting': 'Iluminat Nocturn',
    'charging': 'Stație Încărcare',
    'private': 'Zonă Privată',
    'barrier': 'Barieră Acces',
    'covered': 'Acoperit',
  };

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isFetchingAddress = true);
    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_apiKey"
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final String formattedAddress = data['results'][0]['formatted_address'];
          setState(() {
            _addressController.text = formattedAddress;
          });
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Parking Spot', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text("SAVE TO CLOUD"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saveSpot,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
            onMapCreated: (c) => _mapController = c,
            markers: {
              Marker(
                markerId: const MarkerId("new_spot"),
                position: _currentPosition,
                draggable: true,
                onDragEnd: (newPos) {
                  setState(() => _currentPosition = newPos);
                  _reverseGeocode(newPos);
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Trage de pinul de pe hartă pentru a seta locația exactă",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 420,
              height: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("New Asset Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Position pin on map to set location", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 48),
                    _buildTextField("Asset Name *", _nameController, Icons.label_important_outline),
                    const SizedBox(height: 24),
                    _buildTextField("Description", _descriptionController, Icons.description_outlined, maxLines: 4),
                    const SizedBox(height: 24),
                    _buildTextField("Physical Address *", _addressController, Icons.map_outlined),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 12),
                      child: Text(
                        "COORDS: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}",
                        style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Price (RON) *", _priceController, Icons.payments_outlined, isNumber: true)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildTextField("Spot Number (Optional)", _spotNumberController, Icons.tag)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text("FACILITIES / TAGS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableFacilities.entries.map((entry) {
                        final bool isSelected = _selectedFacilities.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          checkmarkColor: Colors.white,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedFacilities.add(entry.key);
                              } else {
                                _selectedFacilities.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    const Text("STREET VIEW PREVIEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        "https://maps.googleapis.com/maps/api/streetview?size=600x300&location=${_currentPosition.latitude},${_currentPosition.longitude}&key=$_apiKey",
                        height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(height: 180, color: Colors.grey[200], child: const Icon(Icons.streetview)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("AVAILABILITY OVERRIDES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Disponibil Permanent (24/7)", style: TextStyle(fontSize: 14)),
                            value: _isAlwaysAvailable,
                            activeThumbColor: Colors.green,
                            onChanged: (val) => setState(() => _isAlwaysAvailable = val),
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Dezactivează Temporar (Offline)", style: TextStyle(fontSize: 14)),
                            value: _isManuallyDisabled,
                            activeThumbColor: Colors.red,
                            onChanged: (val) => setState(() => _isManuallyDisabled = val),
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Nevalabil (General)", style: TextStyle(fontSize: 14)),
                            subtitle: const Text("Blochează orice rezervare pe acest loc", style: TextStyle(fontSize: 11)),
                            value: _isUnderMaintenance,
                            activeThumbColor: Colors.orange,
                            onChanged: (val) => setState(() => _isUnderMaintenance = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text("IMAGES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("URL", _imageController, Icons.link)),
                        IconButton(
                          onPressed: () {
                            if (_imageController.text.isNotEmpty) {
                              setState(() => _imageUrls.add(_imageController.text));
                              _imageController.clear();
                            }
                          },
                          icon: const Icon(Icons.add_box, color: Color(0xFF2563EB), size: 32),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _imageUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover)),
                              Positioned(right: 4, top: 4, child: InkWell(
                                onTap: () => setState(() => _imageUrls.remove(url)),
                                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                              ))
                            ],
                          ),
                        )).toList(),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveSpot() async {
    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    final double? price = double.tryParse(_priceController.text);

    if (name.isEmpty || address.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Te rugăm să completezi Numele, Adresa și Prețul!"), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      final schedule = {
        'isAlwaysAvailable': _isAlwaysAvailable,
        'isManuallyDisabled': _isManuallyDisabled,
        'Monday': {'active': true, 'start': '09:00', 'end': '17:00'},
        'Tuesday': {'active': true, 'start': '09:00', 'end': '17:00'},
        'Wednesday': {'active': true, 'start': '09:00', 'end': '17:00'},
        'Thursday': {'active': true, 'start': '09:00', 'end': '17:00'},
        'Friday': {'active': true, 'start': '09:00', 'end': '17:00'},
        'Saturday': {'active': false, 'start': '09:00', 'end': '17:00'},
        'Sunday': {'active': false, 'start': '09:00', 'end': '17:00'},
      };

      await FirebaseFirestore.instance.collection('parking_spaces').add({
        'name': name,
        'description': _descriptionController.text.trim(),
        'address': address,
        'pricePerHour': price,
        'spotNumber': _spotNumberController.text.trim(),
        'totalSpots': 1,
        'availableSpots': 1,
        'facilities': _selectedFacilities,
        'weeklySchedule': schedule,
        'latitude': _currentPosition.latitude,
        'longitude': _currentPosition.longitude,
        'location': GeoPoint(_currentPosition.latitude, _currentPosition.longitude),
        'isUnderMaintenance': _isUnderMaintenance,
        'status': _isUnderMaintenance ? 'unavailable' : 'available',
        'imageUrls': _imageUrls,
        'ownerId': uid,
        'ownerName': 'Admin', // In the future fetch from user doc
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New parking spot added!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
}
