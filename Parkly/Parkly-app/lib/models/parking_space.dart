import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingSpace {
  final String id;
  final List<String> docIds;
  final String ownerId;
  final String ownerName;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double pricePerHour;
  final int totalSpots;
  final int availableSpots;
  final String imageUrl;
  final List<String> imageUrls;
  final bool isUnderMaintenance;
  final String description;
  final String ownerUsername;
  final Map<String, dynamic> weeklySchedule;
  final String spotNumber; // ex: "234"
  final List<String> facilities; // ex: ["videocam", "lighting"]

  ParkingSpace({
    required this.id,
    required this.docIds,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.pricePerHour,
    required this.totalSpots,
    required this.availableSpots,
    this.imageUrl = 'https://via.placeholder.com/150',
    this.imageUrls = const [],
    this.isUnderMaintenance = false,
    this.description = '',
    this.ownerUsername = '',
    this.weeklySchedule = const {},
    this.spotNumber = '',
    this.facilities = const [],
  });

  factory ParkingSpace.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    double lat = 0;
    double lng = 0;
    if (data['location'] is GeoPoint) {
      lat = (data['location'] as GeoPoint).latitude;
      lng = (data['location'] as GeoPoint).longitude;
    } else {
      lat = (data['latitude'] ?? 0).toDouble();
      lng = (data['longitude'] ?? 0).toDouble();
    }

    List<String> images = [];
    if (data['imageUrls'] != null) {
      images = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'] != 'https://via.placeholder.com/150') {
      images = [data['imageUrl']];
    }

    Map<String, dynamic> schedule = {};
    if (data['weeklySchedule'] != null) {
      schedule = Map<String, dynamic>.from(data['weeklySchedule']);
    }

    return ParkingSpace(
      id: doc.id,
      docIds:
          data['docIds'] != null ? List<String>.from(data['docIds']) : [doc.id],
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? 'Proprietar Parkly',
      ownerUsername: data['ownerUsername'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: lat,
      longitude: lng,
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      totalSpots: data['totalSpots'] ?? 1,
      availableSpots: data['availableSpots'] ?? 0,
      imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/150',
      imageUrls: images,
      isUnderMaintenance: data['isUnderMaintenance'] ?? false,
      description: data['description'] ?? '',
      weeklySchedule: schedule,
      spotNumber: data['spotNumber'] ?? '',
      facilities: List<String>.from(data['facilities'] ?? []),
    );
  }

  // Fallback pentru UI vechi
  String get startTime => weeklySchedule['Monday']?['start'] ?? '00:00';
  String get endTime => weeklySchedule['Monday']?['end'] ?? '23:59';

  bool get isAvailable => availableSpots > 0 && !isUnderMaintenance && !isClosed;
  
  bool get isClosed {
    if (weeklySchedule['isManuallyDisabled'] == true) return true;
    if (weeklySchedule['isAlwaysAvailable'] == true) return false;

    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    final dayData = weeklySchedule[dayName];

    if (dayData == null || dayData is! Map) return true;

    try {
      if (dayData['active'] == false) return true;
      
      final String startTimeStr = dayData['start'] ?? '00:00';
      final String endTimeStr = dayData['end'] ?? '23:59';
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      final schedStart = DateTime(now.year, now.month, now.day, startHour, startMin);
      DateTime schedEnd = DateTime(now.year, now.month, now.day, endHour, endMin);

      if (schedEnd.isBefore(schedStart)) {
        schedEnd = schedEnd.add(const Duration(days: 1));
      }

      return now.isBefore(schedStart) || now.isAfter(schedEnd);
    } catch (e) {
      return false;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  double get occupancyRate =>
      totalSpots > 0 ? (totalSpots - availableSpots) / totalSpots : 0;

  String getStreetViewUrl() {
    const apiKey = "AIzaSyBaCn_LG8dCxqG6k-dixYdLfuJ8d4Gn83Y";
    return "https://maps.googleapis.com/maps/api/streetview?size=600x400&location=$latitude,$longitude&fov=90&heading=235&pitch=10&key=$apiKey";
  }

  List<String> getAllDisplayImages() {
    List<String> all = List.from(imageUrls);
    all.add(getStreetViewUrl());
    return all.where((img) => img.isNotEmpty).toList();
  }
}
