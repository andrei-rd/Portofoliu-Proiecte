import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/parking_service.dart';
import '../services/language_service.dart';
import '../models/parking_space.dart';
import 'parking_details_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart';

import '../widgets/parking_card.dart';

import 'main_navigation_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  Position? _userPosition;

  // State pentru filtre
  double _maxPrice = 50.0;
  bool _onlyAvailable = true;
  String _sortBy = 'distance'; // 'distance' sau 'price'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
    _initLocationStream();
  }

  void _initLocationStream() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      try {
        Position? pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high));
        if (mounted) setState(() => _userPosition = pos);
      } catch (e) {
        debugPrint("Error getting initial location: $e");
      }

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _userPosition = position;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet(LanguageService lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.translate('filters'),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _maxPrice = 50.0;
                            _onlyAvailable = true;
                            _sortBy = 'distance';
                          });
                          setState(() {});
                        },
                        child: Text(lang.translate('reset_filters')),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "${lang.translate('price_range')}: ${_maxPrice.toInt()} RON",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Slider(
                    value: _maxPrice,
                    min: 5.0,
                    max: 100.0,
                    divisions: 19,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setSheetState(() => _maxPrice = val);
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  Text(
                    lang.translate('sort_by'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(lang.translate('sort_by_distance')),
                        selected: _sortBy == 'distance',
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() => _sortBy = 'distance');
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(lang.translate('price')),
                        selected: _sortBy == 'price',
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() => _sortBy = 'price');
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text(lang.translate('show_available_only')),
                    value: _onlyAvailable,
                    activeThumbColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setSheetState(() => _onlyAvailable = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lang.translate('apply_filters'),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ParkingService parkingService = ParkingService();
    final lang = LanguageService();

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(seconds: 1));
              },
              color: const Color(0xFF2563EB),
              child: StreamBuilder<List<ParkingSpace>>(
                stream: parkingService.getParkingSpaces(),
                builder: (context, parkingSnapshot) {
                  // APLICĂM FILTRAREA ȘI SORTAREA O SINGURĂ DATĂ PENTRU TOT ECRANUL
                  List<ParkingSpace> filteredSpaces = [];
                  if (parkingSnapshot.hasData) {
                    final now = DateTime.now();
                    final nextHour = now.add(const Duration(hours: 1));

                    filteredSpaces = parkingSnapshot.data!.where((space) {
                      if (space.isClosed) return false;
                      
                      final matchesText = space.name
                              .toLowerCase()
                              .contains(_searchText) ||
                          space.address.toLowerCase().contains(_searchText);
                      
                      // Calculăm prețul dinamic curent pentru filtrare precisă
                      final details = parkingService.getPriceDetails(space, now, nextHour);
                      final currentPrice = details.finalPrice - details.serviceFee;
                      
                      final matchesPrice = currentPrice <= _maxPrice;
                      final matchesAvailability =
                          _onlyAvailable ? space.isAvailable : true;

                      return matchesText && matchesPrice && matchesAvailability;
                    }).toList();

                    if (_sortBy == 'distance' && _userPosition != null) {
                      filteredSpaces.sort((a, b) {
                        double distA = Geolocator.distanceBetween(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                            a.latitude,
                            a.longitude);
                        double distB = Geolocator.distanceBetween(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                            b.latitude,
                            b.longitude);
                        return distA.compareTo(distB);
                      });
                    } else if (_sortBy == 'price') {
                      filteredSpaces.sort((a, b) =>
                          a.pricePerHour.compareTo(b.pricePerHour));
                    }
                  }

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // HEADER
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(user?.uid)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              // Folosim datele din Auth ca prim fallback pentru a evita flicker-ul
                              String name = user?.displayName ?? lang.translate('driver_welcome');
                              String? photoURL = user?.photoURL;

                              if (userSnapshot.hasData &&
                                  userSnapshot.data!.exists) {
                                final data = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                name = data['displayName'] ??
                                    data['name'] ??
                                    name;
                                photoURL = data['photoURL'] ?? photoURL;
                              }
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name == lang.translate('driver_welcome') && userSnapshot.connectionState == ConnectionState.waiting
                                            ? '${lang.translate('hello')}!' 
                                            : '${lang.translate('hello')}, ${name.split(' ')[0]}!',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Brasov, Romania',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('notifications')
                                            .where('target',
                                                whereIn: [user?.uid ?? '', 'all'])
                                            .where('isRead', isEqualTo: false)
                                            .snapshots(),
                                        builder: (context, notifSnapshot) {
                                          final now = DateTime.now();
                                          int unreadCount = 0;
                                          
                                          if (notifSnapshot.hasData) {
                                            unreadCount = notifSnapshot.data!.docs.where((doc) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              final List hiddenBy = data['hiddenBy'] ?? [];
                                              if (hiddenBy.contains(user?.uid)) return false;
                                              
                                              final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                                              if (createdAt != null && createdAt.toDate().isAfter(now)) {
                                                return false;
                                              }
                                              return true;
                                            }).length;
                                          }

                                          return Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade200),
                                                ),
                                                child: IconButton(
                                                  onPressed: () =>
                                                      Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            const MessagesScreen()),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.notifications_none_rounded,
                                                      color: Color(0xFF2563EB),
                                                      size: 22),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                              ),
                                              if (unreadCount > 0)
                                                Positioned(
                                                  top: -5,
                                                  right: -5,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 18,
                                                      minHeight: 18,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () {
                                          // Navigăm la ultimul tab (Profil) - index 4
                                          final navState = context.findAncestorStateOfType<MainNavigationScreenState>();
                                          if (navState != null) {
                                            navState.setIndex(4);
                                          }
                                        },
                                        child: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.grey.shade200),
                                            image: photoURL != null
                                                ? DecorationImage(
                                                    image: NetworkImage(photoURL),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: photoURL == null
                                              ? const Icon(
                                                  Icons.local_parking_rounded,
                                                  color: Color(0xFF2563EB),
                                                  size: 24,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // SEARCH BAR
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: lang.translate('search_hint'),
                                      border: InputBorder.none,
                                      icon: const Icon(Icons.search,
                                          color: Colors.grey),
                                      suffixIcon: _searchText.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () =>
                                                  _searchController.clear(),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _showFilterSheet(lang),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.tune,
                                      color: Colors.white),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      // MAP PREVIEW
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: const MiniMapPreview(),
                            ),
                          ),
                        ),
                      ),

                      // STATS
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Builder(builder: (context) {
                            int availableCount = 0;
                            int myReservations = 0;
                            String priceRange = "---";

                            if (filteredSpaces.isNotEmpty) {
                              // Numărăm locurile fizic disponibile doar din cele filtrate
                              availableCount = filteredSpaces
                                  .where((s) => s.isAvailable)
                                  .length;

                              final now = DateTime.now();
                              final nextHour = now.add(const Duration(hours: 1));
                              
                              final prices = filteredSpaces.map((s) {
                                final details = parkingService.getPriceDetails(s, now, nextHour);
                                return details.finalPrice - details.serviceFee;
                              }).toList();

                              final minPrice = prices
                                  .reduce((a, b) => a < b ? a : b)
                                  .toInt();
                              final maxPrice = prices
                                  .reduce((a, b) => a > b ? a : b)
                                  .toInt();
                              priceRange = minPrice == maxPrice
                                  ? "$minPrice"
                                  : "$minPrice-$maxPrice";
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('reservations')
                                  .where('userId', isEqualTo: user?.uid)
                                  .where('status', isEqualTo: 'activ')
                                  .snapshots(),
                              builder: (context, resSnapshot) {
                                if (resSnapshot.hasData) {
                                  final now = DateTime.now();
                                  myReservations =
                                      resSnapshot.data!.docs.where((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final Timestamp? end =
                                        data['endTime'] as Timestamp?;
                                    return end != null &&
                                        end.toDate().isAfter(now);
                                  }).length;
                                }
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStat(availableCount.toString(),
                                        lang.translate('available')),
                                    _buildStat(myReservations.toString(),
                                        lang.translate('my_res')),
                                    _buildStat(
                                        priceRange, lang.translate('price_h')),
                                  ],
                                );
                              },
                            );
                          }),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 25)),

                      // RECOMMENDATIONS HEADER
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(lang.translate('recommendations'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text(lang.translate('see_all'),
                                  style: const TextStyle(
                                      color: Color(0xFF2563EB), fontSize: 13)),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 15)),

                      // RECOMMENDATIONS LIST
                      Builder(builder: (context) {
                        if (!parkingSnapshot.hasData) {
                          return SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(lang.translate('loading_data')),
                          )));
                        }

                        if (filteredSpaces.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.search_off,
                                        size: 50, color: Colors.grey),
                                    const SizedBox(height: 10),
                                    Text(
                                      lang.translate('no_results_filters'),
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final space = filteredSpaces[index];
                                return ParkingCard(
                                  space: space,
                                  userPosition: _userPosition,
                                );
                              },
                              childCount: filteredSpaces.length,
                            ),
                          ),
                        );
                      }),

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class MiniMapPreview extends StatefulWidget {
  const MiniMapPreview({super.key});

  @override
  State<MiniMapPreview> createState() => _MiniMapPreviewState();
}

class _MiniMapPreviewState extends State<MiniMapPreview> {
  GoogleMapController? _controller;
  LatLng _currentPosition = const LatLng(45.6427, 25.5887);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _loading = false;
          });
          _controller
              ?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14));
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _currentPosition, zoom: 14),
              onMapCreated: (controller) => _controller = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              onTap: (_) => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              ),
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                  child: Container(
                    color: Colors.black.withOpacity(0.1),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              )
                            ]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined,
                                size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              lang.translate('view_map'),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
