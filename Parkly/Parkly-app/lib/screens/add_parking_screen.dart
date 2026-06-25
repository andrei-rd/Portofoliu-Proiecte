import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_settings_screen.dart';
import '../services/parking_service.dart';
import '../services/language_service.dart';

import '../models/parking_space.dart';

class AddParkingScreen extends StatefulWidget {
  final ParkingSpace? parkingSpace;
  const AddParkingScreen({super.key, this.parkingSpace});

  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _parkingService = ParkingService();
  final _picker = ImagePicker();
  final lang = LanguageService();

  final _nameKey = GlobalKey();
  final _addressKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _priceKey = GlobalKey();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _priceController;
  late final TextEditingController _spotsController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _spotNumberController;

  final _nameFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _priceFocus = FocusNode();

  List<String> _selectedFacilities = [];

  final List<Map<String, dynamic>> _allFacilities = [
    {
      'id': 'videocam',
      'label': 'Supraveghere 24/7',
      'icon': Icons.videocam_outlined
    },
    {
      'id': 'lighting',
      'label': 'Iluminat nocturn',
      'icon': Icons.wb_sunny_outlined
    },
    {
      'id': 'charging',
      'label': 'Stație încărcare',
      'icon': Icons.electric_car_outlined
    },
    {'id': 'private', 'label': 'Zonă privată', 'icon': Icons.security_outlined},
    {
      'id': 'barrier',
      'label': 'Acces barieră',
      'icon': Icons.door_sliding_outlined
    },
    {'id': 'covered', 'label': 'Acoperit', 'icon': Icons.roofing_outlined},
    {'id': 'paza', 'label': 'Pază umană', 'icon': Icons.person_pin_outlined},
    {'id': 'asphalt', 'label': 'Asfaltat', 'icon': Icons.edit_road_outlined},
    {'id': 'markings', 'label': 'Marcat', 'icon': Icons.border_all_outlined},
    {'id': 'cleaning', 'label': 'Curățenie', 'icon': Icons.cleaning_services_outlined},
    {'id': 'transit', 'label': 'Lângă transport public', 'icon': Icons.directions_bus_outlined},
    {'id': 'disabled', 'label': 'Acces Dizabilități', 'icon': Icons.accessible_outlined},
  ];

  Map<String, dynamic> _weeklySchedule = {
    'Monday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Tuesday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Wednesday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Thursday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Friday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Saturday': {'active': true, 'start': '09:00', 'end': '17:00'},
    'Sunday': {'active': true, 'start': '09:00', 'end': '17:00'},
  };

  // Eliminat setările de disponibilitate manuală (AlwaysAvailable/ManuallyDisabled)
  String? _imageUrl;
  File? _imageFile;

  LatLng _centerLocation = const LatLng(45.6427, 25.5887);
  MapType _currentMapType = MapType.normal;
  bool _isLoading = false;
  bool _isFetchingAddress = false;

  late AnimationController _pinController;
  late Animation<double> _pinAnimation;

  @override
  void initState() {
    super.initState();

    final space = widget.parkingSpace;
    _nameController = TextEditingController(text: space?.name ?? '');
    _addressController = TextEditingController(text: space?.address ?? '');
    _priceController =
        TextEditingController(text: space?.pricePerHour.toString() ?? '');
    _spotsController = TextEditingController(
        text: space?.totalSpots.toString() ?? '1'); // Default la 1 acum
    _descriptionController =
        TextEditingController(text: space?.description ?? '');
    _spotNumberController =
        TextEditingController(text: space?.spotNumber ?? '');

    if (space != null) {
      _selectedFacilities = List<String>.from(space.facilities);
      _centerLocation = LatLng(space.latitude, space.longitude);
      
      if (space.weeklySchedule.isNotEmpty) {
        // Deep copy of schedule entries that are actually Maps (the days)
        space.weeklySchedule.forEach((key, value) {
          if (value is Map) {
            _weeklySchedule[key] = Map<String, dynamic>.from(value);
          }
        });
      }
      if (space.imageUrls.isNotEmpty) {
        _imageUrl = space.imageUrls.first;
      }
    }

    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _pinController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _spotsController.dispose();
    _descriptionController.dispose();
    _spotNumberController.dispose();
    _nameFocus.dispose();
    _addressFocus.dispose();
    _descriptionFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  Future<void> _selectTimeForDay(
      BuildContext context, String day, bool isStart) async {
    final initialTimeStr =
        isStart ? _weeklySchedule[day]!['start'] : _weeklySchedule[day]!['end'];
    final parts = initialTimeStr.split(':');
    final initialTime =
        TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final timeStr =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
        if (isStart) {
          _weeklySchedule[day]!['start'] = timeStr;
        } else {
          _weeklySchedule[day]!['end'] = timeStr;
        }
      });
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    setState(() => _isFetchingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.street}, ${place.locality}, ${place.country}";
        _addressController.text = address;
      }
    } catch (e) {
      debugPrint("Eroare geocoding: $e");
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        // În producție aici am uploada fișierul la Firebase Storage și am lua URL-ul
        _imageUrl =
            "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";
      });
    }
  }

  String _getStreetViewUrl(double lat, double lng) {
    // Folosim cheia din setările proiectului pentru Street View
    const apiKey = "AIzaSyBaCn_LG8dCxqG6k-dixYdLfuJ8d4Gn83Y";
    return "https://maps.googleapis.com/maps/api/streetview?size=600x300&location=$lat,$lng&fov=90&heading=235&pitch=10&key=$apiKey";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
            widget.parkingSpace == null
                ? lang.translate('add_spot')
                : lang.translate('edit'),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // Full Screen Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centerLocation,
              zoom: 15,
            ),
            mapType: _currentMapType,
            onCameraMoveStarted: () {
              _pinController.forward();
            },
            onCameraMove: (position) {
              _centerLocation = position.target;
            },
            onCameraIdle: () {
              _pinController.reverse();
              _updateAddress(_centerLocation);
            },
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Bolt-style Animated Center Pin
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _pinAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _pinAnimation.value - 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 50),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Map Controls
          Positioned(
            top: 100,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'mapTypeToggle',
                  onPressed: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal;
                    });
                  },
                  backgroundColor: Colors.white,
                  child: Icon(
                    _currentMapType == MapType.normal
                        ? Icons.satellite_alt
                        : Icons.map_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                if (_isFetchingAddress)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),

          // Draggable Form
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12, blurRadius: 15, spreadRadius: 5)
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(lang.translate('location_details'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        _buildTextField(_nameController, lang.translate('parking_name'),
                            Icons.business_rounded, 'ex: Parkly Central',
                            key: _nameKey, focusNode: _nameFocus),
                        const SizedBox(height: 16),
                        _buildTextField(
                            _addressController,
                            lang.translate('address_auto'),
                            Icons.location_on_rounded,
                            'Se încarcă...',
                            key: _addressKey,
                            focusNode: _addressFocus,
                            suffix: _isFetchingAddress
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : null),
                        const SizedBox(height: 16),
                        _buildTextField(
                            _descriptionController,
                            lang.translate('detailed_description'),
                            Icons.description_rounded,
                            'ex: Pază, iluminat nocturn, acces facil prin barieră...',
                            key: _descriptionKey,
                            focusNode: _descriptionFocus,
                            maxLines: 3),
                        const SizedBox(height: 16),
                        _buildTextField(
                            _spotNumberController,
                            lang.translate('spot_number_on_pavement'),
                            Icons.pin_rounded,
                            'ex: 234',
                            isRequired: false),
                        const SizedBox(height: 16),
                        Text(lang.translate('facilities'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allFacilities.map((facility) {
                            final isSelected =
                                _selectedFacilities.contains(facility['id']);
                            return FilterChip(
                              label: Text(lang.translate('facility_${facility['id']}')),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedFacilities.add(facility['id']);
                                  } else {
                                    _selectedFacilities.remove(facility['id']);
                                  }
                                });
                              },
                              selectedColor: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(lang.translate('weekly_availability_schedule'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: 1.0,
                          child: IgnorePointer(
                            ignoring: false,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: Text(lang.translate(day.toLowerCase()),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                        ),
                                        Checkbox(
                                          value: _weeklySchedule[day]?['active'] ?? false,
                                          activeColor: const Color(0xFF2563EB),
                                          onChanged: (val) {
                                            setState(() {
                                              if (_weeklySchedule[day] == null) {
                                                _weeklySchedule[day] = {'active': true, 'start': '09:00', 'end': '17:00'};
                                              }
                                              _weeklySchedule[day]!['active'] = val ?? false;
                                            });
                                          },
                                        ),
                                        if (_weeklySchedule[day]?['active'] == true) ...[
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () => _selectTimeForDay(
                                                context, day, true),
                                            child: Text(
                                                _weeklySchedule[day]!['start'],
                                                style: const TextStyle(
                                                    color: Color(0xFF2563EB))),
                                          ),
                                          const Text(' - '),
                                          GestureDetector(
                                            onTap: () => _selectTimeForDay(
                                                context, day, false),
                                            child: Text(
                                                _weeklySchedule[day]!['end'],
                                                style: const TextStyle(
                                                    color: Color(0xFF2563EB))),
                                          ),
                                        ] else
                                          Expanded(
                                              child: Center(
                                                  child: Text(lang.translate('closed'),
                                                      style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 12)))),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(lang.translate('street_view_preview'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.grey.shade200,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              _getStreetViewUrl(_centerLocation.latitude,
                                  _centerLocation.longitude),
                              fit: BoxFit.cover,
                              errorBuilder: (context, e, s) => const Center(
                                  child: Icon(Icons.streetview,
                                      color: Colors.grey, size: 40)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(lang.translate('parking_photo'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: _imageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(_imageFile!,
                                        fit: BoxFit.cover))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo_outlined,
                                          color: Color(0xFF2563EB)),
                                      const SizedBox(height: 8),
                                      Text(lang.translate('parking_photo'),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(
                                    _priceController,
                                    '${lang.translate('price')} (RON/h)',
                                    Icons.payments_outlined,
                                    '10',
                                    key: _priceKey,
                                    focusNode: _priceFocus,
                                    isNumber: true)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(lang.translate('confirm_and_save'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, String hint,
      {bool isNumber = false,
      Widget? suffix,
      int maxLines = 1,
      bool isRequired = true,
      FocusNode? focusNode,
      Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.all(12), child: suffix)
                : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return lang.translate('required_field_error');
            }
            return null;
          },
        ),
      ],
    );
  }

  void _scrollToFirstError() {
    GlobalKey? firstErrorKey;
    if (_nameController.text.trim().isEmpty) {
      firstErrorKey = _nameKey;
    } else if (_addressController.text.trim().isEmpty) {
      firstErrorKey = _addressKey;
    } else if (_descriptionController.text.trim().isEmpty) {
      firstErrorKey = _descriptionKey;
    } else if (_priceController.text.trim().isEmpty) {
      firstErrorKey = _priceKey;
    }

    if (firstErrorKey != null && firstErrorKey.currentContext != null) {
      Scrollable.ensureVisible(
        firstErrorKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      // Focus after scroll
      if (firstErrorKey == _nameKey)
        _nameFocus.requestFocus();
      else if (firstErrorKey == _addressKey)
        _addressFocus.requestFocus();
      else if (firstErrorKey == _descriptionKey)
        _descriptionFocus.requestFocus();
      else if (firstErrorKey == _priceKey) _priceFocus.requestFocus();
    }
  }

  String _translateDay(String day) {
    switch (day) {
      case 'Monday':
        return 'Luni';
      case 'Tuesday':
        return 'Marți';
      case 'Wednesday':
        return 'Miercuri';
      case 'Thursday':
        return 'Joi';
      case 'Friday':
        return 'Vineri';
      case 'Saturday':
        return 'Sâmbătă';
      case 'Sunday':
        return 'Duminică';
      default:
        return day;
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Verificare număr de telefon
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final phone = userDoc.data()?['phoneNumber'];
          if (phone == null || phone.toString().isEmpty || phone.toString().length < 10) {
            if (mounted) {
              setState(() => _isLoading = false);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text("Număr de telefon necesar", style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text("Pentru a publica un loc de parcare, trebuie să ai un număr de telefon valid salvat în profil (minim 10 cifre cu tot cu prefix)."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anulează")),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      child: const Text("Mergi la profil", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }

        List<String> images = widget.parkingSpace?.imageUrls ?? [];
        if (_imageUrl != null && !images.contains(_imageUrl)) {
          images = [_imageUrl!]; // Simplified for now
        }

        final Map<String, dynamic> data = {
          'name': _nameController.text,
          'address': _addressController.text,
          'description': _descriptionController.text,
          'spotNumber': _spotNumberController.text,
          'facilities': _selectedFacilities,
          'weeklySchedule': {
            ..._weeklySchedule,
          },
          'latitude': _centerLocation.latitude,
          'longitude': _centerLocation.longitude,
          'pricePerHour': double.parse(_priceController.text),
          'totalSpots': 1,
          'availableSpots': 1,
          'imageUrl': images.isNotEmpty
              ? images.first
              : 'https://via.placeholder.com/400',
          'imageUrls': images,
          'isAvailable': true,
        };

        if (widget.parkingSpace == null) {
          await _parkingService.addSingleSpot(data);
        } else {
          await _parkingService.updateSingleSpot(widget.parkingSpace!.id, data,
              allDocIds: widget.parkingSpace!.docIds);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(widget.parkingSpace == null
                    ? lang.translate('parking_created_success')
                    : lang.translate('parking_updated_success'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${lang.translate('save_error')} $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      _scrollToFirstError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Te rugăm să completezi toate câmpurile obligatorii marcate cu roșu.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
