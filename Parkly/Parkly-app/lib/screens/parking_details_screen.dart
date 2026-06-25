import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/parking_space.dart';
import '../services/parking_service.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import '../utils/navigation_utils.dart';
import 'chat_conversation_screen.dart';
import 'public_profile_screen.dart';
import 'main_navigation_screen.dart';
import 'reservation_details_screen.dart';
import 'account_settings_screen.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final ParkingSpace parkingSpace;

  const ParkingDetailsScreen({super.key, required this.parkingSpace});

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  final ParkingService _parkingService = ParkingService();
  final DatabaseService _dbService = DatabaseService();
  final LanguageService lang = LanguageService();
  int _selectedHours = 1;
  DateTime _startTime = DateTime.now();
  String? _selectedCarPlate;

  bool _isReserving = false;

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (pickedTime != null) {
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (selectedDateTime.isBefore(now.subtract(const Duration(minutes: 5)))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('past_time_error'))),
          );
        }
        return;
      }

      setState(() {
        _startTime = selectedDateTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceDetails = _parkingService.getPriceDetails(widget.parkingSpace,
        _startTime, _startTime.add(Duration(hours: _selectedHours)));

    final double totalPrice = priceDetails.finalPrice;

    return ListenableBuilder(
      listenable: lang,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  StreamBuilder<List<String>>(
                      stream: _dbService.getUserFavorites(
                          FirebaseAuth.instance.currentUser?.uid ?? ''),
                      builder: (context, snapshot) {
                        final favorites = snapshot.data ?? [];
                        final isFavorite =
                            favorites.contains(widget.parkingSpace.id);
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withValues(alpha: 0.9),
                            child: IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.black,
                                size: 20,
                              ),
                              onPressed: () {
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  _dbService.toggleFavorite(
                                      uid, widget.parkingSpace.id, !isFavorite);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount:
                            widget.parkingSpace.getAllDisplayImages().length,
                        itemBuilder: (context, index) {
                          return Image.network(
                            widget.parkingSpace.getAllDisplayImages()[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                    child: Icon(Icons.image_not_supported)),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              lang.translate('swipe_more_photos'),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.parkingSpace.name,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  // RATING MEDIU
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance.collection('parking_spaces').doc(widget.parkingSpace.id).snapshots(),
                                    builder: (context, snap) {
                                      if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
                                      final data = snap.data!.data() as Map<String, dynamic>;
                                      final double avg = (data['averageRating'] ?? 0.0).toDouble();
                                      final int count = data['reviewCount'] ?? 0;
                                      
                                      if (count == 0) return const SizedBox.shrink();

                                      return Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            avg.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            " ($count)",
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (widget.parkingSpace.spotNumber.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        "${lang.translate('spot_number_label')}: ${widget.parkingSpace.spotNumber}",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        NavigationUtils.showNavigationDialog(
                                      context,
                                      widget.parkingSpace.latitude,
                                      widget.parkingSpace.longitude,
                                      widget.parkingSpace.name,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            color: Color(0xFF2563EB), size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget.parkingSpace.address,
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${((priceDetails.finalPrice - priceDetails.serviceFee) / _selectedHours).toStringAsFixed(1)} RON/h',
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Selector Durată
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lang.translate('start_time'),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectStartTime(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FB),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              color:
                                                  Color(0xFF2563EB), size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            "${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lang.translate('select_hours'),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FB),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: DropdownButton<int>(
                                      value: _selectedHours,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: [1, 2, 3, 4, 5, 6, 8, 12, 24, 48]
                                          .map((h) => DropdownMenuItem<int>(
                                                value: h,
                                                child: Text(
                                                    '$h ${lang.translate('hours')}'),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedHours = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Selector Mașină
                        Text(lang.translate('select_car'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: _dbService.getUserCars(
                              FirebaseAuth.instance.currentUser?.uid ?? ''),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                    lang.translate('no_cars_added_error'),
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13)),
                              );
                            }

                            final cars = snapshot.data!.docs;
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FB),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedCarPlate,
                                isExpanded: true,
                                underline: const SizedBox(),
                                hint: Text(lang.translate('choose_plate')),
                                items: cars.map((doc) {
                                  final car =
                                      doc.data() as Map<String, dynamic>;
                                  final plate = (car['plate'] ?? '').toString();
                                  return DropdownMenuItem<String>(
                                    value: plate,
                                    child: Text(plate),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedCarPlate = val);
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Owner Info
                        widget.parkingSpace.ownerId.isEmpty
                            ? GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PublicProfileScreen(userId: 'parkly_support'),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          image: const DecorationImage(
                                            image: AssetImage('lib/assets/logo.png'),
                                            fit: BoxFit.cover,
                                          ),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lang.translate('owner'),
                                                style: const TextStyle(
                                                    color: Colors.grey, fontSize: 12)),
                                            const Text("Echipa Parkly",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15)),
                                            const Text("Parkly Support",
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const ChatConversationScreen(
                                                receiverId: 'parkly_support',
                                                receiverName: 'Echipa Parkly',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.support_agent_rounded,
                                              color: Color(0xFF2563EB), size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.parkingSpace.ownerId)
                                    .snapshots(),
                                builder: (context, ownerSnapshot) {
                                  String ownerName = widget.parkingSpace.ownerName;
                                  String? ownerPhoto;
                                  String ownerEmail = "";

                                  if (ownerSnapshot.hasData && ownerSnapshot.data!.exists) {
                                    final ownerData = ownerSnapshot.data!.data() as Map<String, dynamic>;
                                    ownerName = ownerData['displayName'] ?? ownerData['name'] ?? ownerName;
                                    ownerPhoto = ownerData['photoURL'];
                                    ownerEmail = ownerData['email'] ?? "";
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      if (widget.parkingSpace.ownerId.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PublicProfileScreen(userId: widget.parkingSpace.ownerId),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FB),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 45,
                                            height: 45,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: ownerPhoto == null ? const Color(0xFF2563EB) : Colors.white,
                                              image: ownerPhoto != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(ownerPhoto),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: ownerPhoto == null
                                                ? Center(
                                                    child: Text(
                                                      ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(lang.translate('owner'),
                                                    style: const TextStyle(
                                                        color: Colors.grey, fontSize: 12)),
                                                Text(ownerName,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15)),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              if (widget.parkingSpace.ownerId.isNotEmpty && widget.parkingSpace.ownerId != FirebaseAuth.instance.currentUser?.uid) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatConversationScreen(
                                                      receiverId: widget.parkingSpace.ownerId,
                                                      receiverName: ownerName,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.chat_bubble_outline,
                                                  color: Color(0xFF2563EB), size: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                        const SizedBox(height: 32),
                        Text(lang.translate('about_location'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          widget.parkingSpace.description.isNotEmpty
                              ? widget.parkingSpace.description
                              : (lang.currentLocale.languageCode == 'ro'
                                  ? 'Această parcare privată este situată într-o zonă sigură și accesibilă. Oferă monitorizare video 24/7 și iluminat nocturn excelent pentru siguranța mașinii tale.'
                                  : 'This private parking is located in a safe and accessible area. It offers 24/7 video monitoring and excellent night lighting for your car\'s safety.'),
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              height: 1.6,
                              fontSize: 14),
                        ),

                        const SizedBox(height: 32),
                        Text(lang.translate('availability_schedule'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              _buildScheduleRow(lang.translate('monday'),
                                  widget.parkingSpace.weeklySchedule['Monday']),
                              _buildScheduleRow(lang.translate('tuesday'),
                                  widget.parkingSpace.weeklySchedule['Tuesday']),
                              _buildScheduleRow(
                                  lang.translate('wednesday'),
                                  widget.parkingSpace
                                      .weeklySchedule['Wednesday']),
                              _buildScheduleRow(
                                  lang.translate('thursday'),
                                  widget.parkingSpace
                                      .weeklySchedule['Thursday']),
                              _buildScheduleRow(lang.translate('friday'),
                                  widget.parkingSpace.weeklySchedule['Friday']),
                              _buildScheduleRow(
                                  lang.translate('saturday'),
                                  widget.parkingSpace
                                      .weeklySchedule['Saturday']),
                              _buildScheduleRow(
                                  lang.translate('sunday'),
                                  widget.parkingSpace.weeklySchedule['Sunday'],
                                  isLast: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(lang.translate('facilities'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (widget.parkingSpace.facilities.isEmpty)
                          Text(lang.translate('no_facilities'),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13))
                        else
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: widget.parkingSpace.facilities.map((fId) {
                              final f = _getFacilityData(fId);
                              return _buildFeatureItem(f['icon'], f['label']);
                            }).toList(),
                          ),

                        const SizedBox(height: 32),
                        Text(lang.translate('available'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${widget.parkingSpace.availableSpots} ${lang.translate('free_spots')}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${lang.translate('total_spots')}: ${widget.parkingSpace.totalSpots}',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: widget.parkingSpace.occupancyRate,
                                  backgroundColor: Colors.grey.shade200,
                                  color: widget.parkingSpace.isUnderMaintenance
                                      ? Colors.orange
                                      : (widget.parkingSpace.isAvailable
                                          ? const Color(0xFF22C55E)
                                          : Colors.red),
                                  minHeight: 12,
                                ),
                              ),
                              if (widget.parkingSpace.isUnderMaintenance)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          color: Colors.orange, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          lang.translate('maintenance_notice'),
                                          style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(lang.currentLocale.languageCode == 'ro' ? 'Recenzii' : 'Reviews',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('reviews')
                              .where('spotId', isEqualTo: widget.parkingSpace.id)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text("Eroare la încărcare recenzii. Verifică index-ul Firestore: ${snapshot.error}", 
                                  style: const TextStyle(fontSize: 10, color: Colors.red)),
                              );
                            }
                            if (!snapshot.hasData) return const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ));
                            final docs = snapshot.data!.docs;

                            if (docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    lang.currentLocale.languageCode == 'ro' ? "Nicio recenzie încă." : "No reviews yet.",
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (context, index) => const Divider(height: 30),
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundColor: Colors.grey.shade200,
                                              backgroundImage: data['userPhoto'] != null ? NetworkImage(data['userPhoto']) : null,
                                              child: data['userPhoto'] == null ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(data['userName'] ?? "Utilizator", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                        Text(DateFormat('dd.MM.yyyy').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: List.generate(5, (starIdx) => Icon(
                                        starIdx < (data['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      )),
                                    ),
                                    if (data['comment'] != null && data['comment'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(data['comment'], style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.translate('total_payment'),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      Text('${totalPrice.toStringAsFixed(2)} RON',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB))),
                      if (priceDetails.reasons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            priceDetails.reasons
                                .where((r) =>
                                    r.contains('-') ||
                                    r.toLowerCase().contains('reducere') ||
                                    r.toLowerCase().contains('discount'))
                                .join(', '),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (widget.parkingSpace.isAvailable &&
                              _selectedCarPlate != null && !_isReserving)
                          ? () => _checkPhoneAndReserve(priceDetails)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: _isReserving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _selectedCarPlate == null
                                ? lang.translate('choose_car_btn')
                                : lang.translate('reserve_btn'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFacilityData(String id) {
    switch (id) {
      case 'videocam':
        return {
          'label': lang.translate('facility_videocam'),
          'icon': Icons.videocam_outlined
        };
      case 'lighting':
        return {
          'label': lang.translate('facility_lighting'),
          'icon': Icons.wb_sunny_outlined
        };
      case 'charging':
        return {
          'label': lang.translate('facility_charging'),
          'icon': Icons.electric_car_outlined
        };
      case 'private':
        return {
          'label': lang.translate('facility_private'),
          'icon': Icons.security_outlined
        };
      case 'barrier':
        return {
          'label': lang.translate('facility_barrier'),
          'icon': Icons.door_sliding_outlined
        };
      case 'covered':
        return {
          'label': lang.translate('facility_covered'),
          'icon': Icons.roofing_outlined
        };
      case 'paza':
        return {
          'label': lang.translate('facility_paza'),
          'icon': Icons.person_pin_outlined
        };
      case 'asphalt':
        return {
          'label': lang.translate('facility_asphalt'),
          'icon': Icons.edit_road_outlined
        };
      case 'markings':
        return {
          'label': lang.translate('facility_markings'),
          'icon': Icons.border_all_outlined
        };
      case 'cleaning':
        return {
          'label': lang.translate('facility_cleaning'),
          'icon': Icons.cleaning_services_outlined
        };
      case 'transit':
        return {
          'label': lang.translate('facility_transit'),
          'icon': Icons.directions_bus_outlined
        };
      case 'disabled':
        return {
          'label': lang.translate('facility_disabled'),
          'icon': Icons.accessible_outlined
        };
      default:
        return {
          'label': lang.translate('facility_default'),
          'icon': Icons.info_outline
        };
    }
  }

  Widget _buildScheduleRow(String day, Map<String, dynamic>? sched,
      {bool isLast = false}) {
    // Verificare Moduri Speciale (Permanent / Indisponibil)
    final bool isAlways = widget.parkingSpace.weeklySchedule['isAlwaysAvailable'] == true;
    final bool isClosed = widget.parkingSpace.weeklySchedule['isManuallyDisabled'] == true;

    String interval = lang.translate('closed');
    bool active = false;

    if (isAlways) {
      interval = lang.translate('always_available');
      active = true;
    } else if (isClosed) {
      interval = lang.translate('manually_disabled');
      active = false;
    } else {
      active = sched?['active'] ?? false;
      interval = active
          ? "${sched!['start']} - ${sched['end']}"
          : lang.translate('closed');
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.black : Colors.grey,
              )),
          Text(interval,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? const Color(0xFF2563EB) : Colors.grey,
              )),
        ],
      ),
    );
  }

  Future<void> _checkPhoneAndReserve(PriceDetails priceDetails) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isReserving = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      final String? phone = data?['phoneNumber'];

      if (phone == null || phone.isEmpty || phone.length < 10) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Număr de telefon necesar", style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text("Pentru a rezerva un loc de parcare, trebuie să ai un număr de telefon valid salvat în profil (minim 10 cifre cu tot cu prefix)."),
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
      if (mounted) _showCheckoutDialog(context, priceDetails);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Eroare: $e")));
      }
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  void _showCheckoutDialog(BuildContext context, PriceDetails priceDetails) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              lang.translate('checkout_summary'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Builder(builder: (context) {
              final double parkingNet = priceDetails.finalPrice - priceDetails.serviceFee;
              final bool hasDiscount = parkingNet < priceDetails.basePriceTotal;
              
              // Dacă avem Surge (adaos), acesta este inclus automat în "Preț Parcare" 
              // pentru a nu fi vizibil ca un cost extra separat.
              // Dacă avem Discount (reducere), afișăm prețul de bază și scăderea separat.
              final double displayParkingPrice = hasDiscount ? priceDetails.basePriceTotal : parkingNet;

              return Column(
                children: [
                  _buildPriceRow(lang.translate('parking_price'), 
                      "${displayParkingPrice.toStringAsFixed(2)} RON"),
                  
                  if (priceDetails.serviceFee > 0)
                    _buildPriceRow(lang.translate('service_fee'), 
                        "${priceDetails.serviceFee.toStringAsFixed(2)} RON", isFee: true),

                  if (hasDiscount)
                    Builder(builder: (context) {
                      String label = lang.translate('discount_adjustment');
                      if (priceDetails.reasons.isNotEmpty) {
                        // Căutăm motivul care conține o reducere (negativ)
                        final specificReason = priceDetails.reasons.firstWhere(
                          (r) => r.contains('-') || r.toLowerCase().contains('reducere') || r.toLowerCase().contains('discount'),
                          orElse: () => priceDetails.reasons.first,
                        );
                        if (specificReason.isNotEmpty) label = specificReason;
                      }
                      
                      return _buildPriceRow(
                          label,
                          "${(priceDetails.basePriceTotal - parkingNet).abs().toStringAsFixed(2)} RON",
                          isAdjustment: true,
                          isNegative: true);
                    }),
                ],
              );
            }),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.translate('total_payment'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${priceDetails.finalPrice.toStringAsFixed(2)} RON",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB))),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close bottom sheet
                  _processReservation(priceDetails.finalPrice);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  lang.translate('confirm_and_pay'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value,
      {bool isFee = false, bool isAdjustment = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isFee)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isAdjustment ? (isNegative ? "- $value" : "+ $value") : value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isAdjustment
                  ? (isNegative ? Colors.green : Colors.red)
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processReservation(double totalPrice) async {
    try {
      final res = await _parkingService.reserveSpot(
          widget.parkingSpace, totalPrice,
          startTime: _startTime,
          endTime: _startTime.add(Duration(hours: _selectedHours)),
          carPlate: _selectedCarPlate);
      if (context.mounted) {
        _showSuccessDialog(context, res['id'], res['data']);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: ${e.toString()}')),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String reservationId, Map<String, dynamic> reservationData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 80),
            const SizedBox(height: 24),
            Text(
              lang.translate('reservation_confirmed'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              lang.translate('res_success_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back from details
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReservationDetailsScreen(
                              reservationId: reservationId,
                              reservationData: reservationData,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(lang.translate('details'),
                          style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back from details
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: Text(lang.translate('close'),
                          style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
