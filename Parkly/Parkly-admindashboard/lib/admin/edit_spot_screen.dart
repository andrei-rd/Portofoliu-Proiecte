import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class EditSpotScreen extends StatefulWidget {
  final String spotId;
  final Map<String, dynamic> initialData;

  const EditSpotScreen({super.key, required this.spotId, required this.initialData});

  @override
  State<EditSpotScreen> createState() => _EditSpotScreenState();
}

class _EditSpotScreenState extends State<EditSpotScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(45.6427, 25.5887);
  bool _isFetchingAddress = false;
  bool _mapGesturesEnabled = true;
  MapType _currentMapType = MapType.normal;
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _spotNumberController = TextEditingController();
  final _imageController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  late bool _isUnderMaintenance;
  late bool _isAlwaysAvailable;
  late bool _isManuallyDisabled;
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

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialData['name'] ?? '';
    _priceController.text = (widget.initialData['pricePerHour'] ?? 0).toString();
    _spotNumberController.text = (widget.initialData['spotNumber'] ?? '').toString();
    _isUnderMaintenance = widget.initialData['isUnderMaintenance'] ?? false;
    final schedule = widget.initialData['weeklySchedule'] as Map<String, dynamic>? ?? {};
    _isAlwaysAvailable = schedule['isAlwaysAvailable'] ?? false;
    _isManuallyDisabled = schedule['isManuallyDisabled'] ?? false;
    
    _addressController.text = widget.initialData['address'] ?? '';
    _descriptionController.text = widget.initialData['description'] ?? '';
    _imageUrls = List<String>.from(widget.initialData['imageUrls'] ?? []);
    _selectedFacilities = List<String>.from(widget.initialData['facilities'] ?? []);
    
    double lat = widget.initialData['latitude'] ?? widget.initialData['lat'] ?? 45.6427;
    double lng = widget.initialData['longitude'] ?? widget.initialData['lng'] ?? 25.5887;
    _currentPosition = LatLng(lat, lng);
  }

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
        title: Text('Editing Asset: ${widget.initialData['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text("UPDATE FIREBASE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saveChanges,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAP BACKGROUND
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 17.5),
            onMapCreated: (c) => _mapController = c,
            markers: {
              Marker(
                markerId: const MarkerId("selected_spot"),
                position: _currentPosition,
                draggable: true,
                infoWindow: const InfoWindow(title: "Trage de pin pentru precizie"),
                onDragEnd: (newPos) {
                  setState(() => _currentPosition = newPos);
                  _reverseGeocode(newPos);
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: _currentMapType,
            zoomGesturesEnabled: _mapGesturesEnabled,
            scrollGesturesEnabled: _mapGesturesEnabled,
            rotateGesturesEnabled: _mapGesturesEnabled,
            tiltGesturesEnabled: _mapGesturesEnabled,
          ),

          // MAP STYLE TOGGLE (ABOVE PANEL)
          Positioned(
            top: 16,
            right: 460, // Positioned to the left of the right panel (420 width + margins)
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _currentMapType = _currentMapType == MapType.normal
                      ? MapType.satellite
                      : MapType.normal;
                });
              },
              child: Icon(
                _currentMapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),

          // INFO OVERLAY (TOP LEFT)
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
                    "Ține apăsat pe pinul albastru pentru a-l muta cu precizie",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL (DETAILS)
          Align(
            alignment: Alignment.centerRight,
            child: MouseRegion(
              onEnter: (_) => setState(() => _mapGesturesEnabled = false),
              onExit: (_) => setState(() => _mapGesturesEnabled = true),
              child: Container(
                width: 420,
                height: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        spreadRadius: 5)
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Live Asset Data",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("Move map to update location automatically",
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const Divider(height: 48),
                      _buildTextField("Asset Name *", _nameController,
                          Icons.label_important_outline),
                      const SizedBox(height: 24),
                      _buildTextField("Description", _descriptionController,
                          Icons.description_outlined,
                          maxLines: 4),
                      const SizedBox(height: 24),

                      // Address Field (Editable)
                      Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          _buildTextField("Physical Address *",
                              _addressController, Icons.map_outlined),
                          if (_isFetchingAddress)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),
                        ],
                      ),

                      // Coordinates (Secondary Info)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 12),
                        child: Text(
                          "COORDS: ${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  "Price (RON) *",
                                  _priceController,
                                  Icons.payments_outlined,
                                  isNumber: true)),
                          const SizedBox(width: 20),
                          Expanded(
                              child: _buildTextField("Spot Number (Optional)",
                                  _spotNumberController, Icons.tag)),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text("FACILITIES / TAGS",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableFacilities.entries.map((entry) {
                          final bool isSelected =
                              _selectedFacilities.contains(entry.key);
                          return FilterChip(
                            label: Text(entry.value,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87)),
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
                            const Text("AVAILABILITY OVERRIDES",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1)),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Disponibil Permanent (24/7)",
                                  style: TextStyle(fontSize: 14)),
                              subtitle: const Text("Ignoră orarul zilnic",
                                  style: TextStyle(fontSize: 11)),
                              value: _isAlwaysAvailable,
                              activeThumbColor: Colors.green,
                              onChanged: (val) =>
                                  setState(() => _isAlwaysAvailable = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Dezactivează Temporar (Offline)",
                                  style: TextStyle(fontSize: 14)),
                              subtitle: const Text("Locul nu va mai apărea pe hartă",
                                  style: TextStyle(fontSize: 11)),
                              value: _isManuallyDisabled,
                              activeThumbColor: Colors.red,
                              onChanged: (val) =>
                                  setState(() => _isManuallyDisabled = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Indisponibil (Nevalabil)",
                                  style: TextStyle(fontSize: 14)),
                              subtitle: const Text("Marchează locul ca neutilizabil",
                                  style: TextStyle(fontSize: 11)),
                              value: _isUnderMaintenance,
                              activeThumbColor: Colors.orange,
                              onChanged: (val) =>
                                  setState(() => _isUnderMaintenance = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text("STREET VIEW PREVIEW",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          "https://maps.googleapis.com/maps/api/streetview?size=600x300&location=${_currentPosition.latitude},${_currentPosition.longitude}&key=$_apiKey",
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: const Icon(Icons.streetview)),
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text("PHOTO GALLERY",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child:
                                  _buildTextField("URL", _imageController, Icons.link)),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (_imageController.text.isNotEmpty) {
                                setState(
                                    () => _imageUrls.add(_imageController.text));
                                _imageController.clear();
                              }
                            },
                            icon: const Icon(Icons.add_box,
                                color: Color(0xFF2563EB), size: 32),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _imageUrls
                              .map((url) => Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(url,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover)),
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: InkWell(
                                            onTap: () => setState(
                                                () => _imageUrls.remove(url)),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle),
                                              child: const Icon(Icons.close,
                                                  size: 14, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
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
      style: const TextStyle(fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB))),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Future<void> _saveChanges() async {
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
      final schedule = Map<String, dynamic>.from(widget.initialData['weeklySchedule'] ?? {});
      schedule['isAlwaysAvailable'] = _isAlwaysAvailable;
      schedule['isManuallyDisabled'] = _isManuallyDisabled;

      await FirebaseFirestore.instance.collection('parking_spaces').doc(widget.spotId).update({
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cloud Data Synchronized!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Error: $e"), backgroundColor: Colors.red));
    }
  }
}
