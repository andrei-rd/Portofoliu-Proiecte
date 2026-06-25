import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parking_space.dart';
import '../services/language_service.dart';
import '../services/database_service.dart';
import '../services/parking_service.dart';
import '../screens/parking_details_screen.dart';

class ParkingCard extends StatelessWidget {
  final ParkingSpace space;
  final Position? userPosition;

  const ParkingCard({
    super.key,
    required this.space,
    this.userPosition,
  });

  IconData _getFacilityIcon(String id) {
    switch (id) {
      case 'videocam':
        return Icons.videocam_outlined;
      case 'lighting':
        return Icons.wb_sunny_outlined;
      case 'charging':
        return Icons.electric_car_outlined;
      case 'private':
        return Icons.security_outlined;
      case 'barrier':
        return Icons.door_sliding_outlined;
      case 'covered':
        return Icons.roofing_outlined;
      case 'paza':
        return Icons.person_pin_outlined;
      case 'asphalt':
        return Icons.edit_road_outlined;
      case 'markings':
        return Icons.border_all_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'transit':
        return Icons.directions_bus_outlined;
      case 'disabled':
        return Icons.accessible_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final parkingService = ParkingService();
    String distanceText = "--- m";

    // Calculăm prețul dinamic curent pentru a fi consistent cu ecranul de detalii
    final now = DateTime.now();
    final priceDetails = parkingService.getPriceDetails(
      space, 
      now, 
      now.add(const Duration(hours: 1))
    );
    final currentHourlyPrice = priceDetails.finalPrice - priceDetails.serviceFee;
    
    if (userPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        userPosition!.latitude,
        userPosition!.longitude,
        space.latitude,
        space.longitude,
      );
      if (distanceInMeters < 1000) {
        distanceText = "${distanceInMeters.toInt()} m";
      } else {
        distanceText = "${(distanceInMeters / 1000).toStringAsFixed(1)} km";
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ParkingDetailsScreen(parkingSpace: space))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 85,
                  height: 85,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      space.getAllDisplayImages().first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                ),
                StreamBuilder<List<String>>(
                  stream: DatabaseService().getUserFavorites(
                      FirebaseAuth.instance.currentUser?.uid ?? ''),
                  builder: (context, snapshot) {
                    final isFavorite =
                        (snapshot.data ?? []).contains(space.id);
                    if (!isFavorite) return const SizedBox.shrink();
                    return Positioned(
                      top: 5,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(distanceText,
                          style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(space.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: 4),
                  Text(space.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        space.weeklySchedule['isAlwaysAvailable'] == true
                            ? Icons.all_inclusive
                            : Icons.wb_sunny_outlined,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      if (space.facilities.isNotEmpty)
                        ...space.facilities.take(3).map((fId) {
                          final icon = _getFacilityIcon(fId);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(icon,
                                size: 14,
                                color: Colors.grey.shade400),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${currentHourlyPrice.toStringAsFixed(1)} lei',
                    style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                Text(lang.translate('per_hour'),
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: space.isUnderMaintenance
                          ? const Color(0xFFFEF9C3)
                          : (space.isAvailable
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      space.isUnderMaintenance
                          ? lang.translate('maintenance_label')
                          : (space.isAvailable
                              ? lang.translate('free')
                              : lang.translate('occupied_label')),
                      style: TextStyle(
                          color: space.isUnderMaintenance
                              ? const Color(0xFF854D0E)
                              : (space.isAvailable
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF991B1B)),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
