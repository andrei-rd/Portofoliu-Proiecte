import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';
import 'edit_spot_screen.dart';
import 'create_spot_screen.dart';
import 'schedule_editor_dialog.dart';

class ManageSpotsScreen extends StatefulWidget {
  const ManageSpotsScreen({super.key});

  @override
  State<ManageSpotsScreen> createState() => _ManageSpotsScreenState();
}

class _ManageSpotsScreenState extends State<ManageSpotsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Colors.white),
            const SizedBox(width: 12),
            const Text(
              'Parking Assets Live Monitor',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 12),
            _buildLiveBadge(),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: adminService.userRole == 'admin' 
            ? _firestore.collection('parking_spaces').snapshots()
            : _firestore.collection('parking_spaces').where('ownerId', isEqualTo: adminService.currentUser?.uid).snapshots(),
        builder: (context, spotSnapshot) {
          if (spotSnapshot.hasError) return Center(child: Text('Error: ${spotSnapshot.error}'));
          if (spotSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('reservations')
                .where('status', isEqualTo: 'activ')
                .snapshots(),
            builder: (context, resSnapshot) {
              final spots = spotSnapshot.data?.docs ?? [];
              final activeReservations = resSnapshot.data?.docs ?? [];
              
              // Map spotId to active reservation
              final Map<String, dynamic> activeSpotsMap = {};
              final DateTime now = DateTime.now();

              for (var res in activeReservations) {
                final data = res.data() as Map<String, dynamic>;
                final String? sId = data['spotId'];
                final Timestamp? endTs = data['endTime'];
                
                if (sId != null && endTs != null) {
                  if (endTs.toDate().isAfter(now)) {
                    activeSpotsMap[sId] = data;
                  }
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(spots.length),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            dataRowMaxHeight: 80,
                            columns: const [
                              DataColumn(label: Text('PHOTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('SPOT #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('OWNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('ADDRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: spots.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final bool isMaintenance = data['isUnderMaintenance'] ?? false;
                              final schedule = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
                              final bool isAlwaysAvailable = schedule['isAlwaysAvailable'] ?? false;
                              final bool isManuallyDisabled = schedule['isManuallyDisabled'] ?? false;
                              
                              // LOGICĂ DINAMICĂ: Dacă există rezervare activă și timp valid -> Ocupat
                              String status = 'available';
                              if (isManuallyDisabled) {
                                status = 'offline';
                              } else if (isMaintenance) {
                                status = 'unavailable';
                              } else if (activeSpotsMap.containsKey(doc.id)) {
                                status = 'full';
                              } else if (isAlwaysAvailable) {
                                status = 'available_24_7';
                              }

                              final List<String> images = List<String>.from(data['imageUrls'] ?? []);
                              final String ownerName = data['ownerName'] ?? data['vendorName'] ?? 'System';
                              final String description = data['description'] ?? 'No description provided';
                              final String? maintenanceReason = data['maintenanceReason'];
                              
                              if (isMaintenance && maintenanceReason == "Low Rating") {
                                status = 'low_rating';
                              }

                              final String thumbUrl = images.isNotEmpty 
                                ? images.first 
                                : "https://maps.googleapis.com/maps/api/streetview?size=100x100&location=${data['latitude'] ?? 45.64},${data['longitude'] ?? 25.58}&key=AIzaSyBaCn_LG8dCxqG6k-dixYdLfuJ8d4Gn83Y";

                              return DataRow(cells: [
                                DataCell(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(thumbUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    data['name'] ?? 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    data['spotNumber'] ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                DataCell(Text(ownerName, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      data['address'] ?? 'No address',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ),
                                ),
                                DataCell(Text('${data['pricePerHour'] ?? 0} RON/hr', style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(_buildStatusChip(status)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_note, color: Color(0xFF2563EB)),
                                        tooltip: 'Edit Details',
                                        onPressed: () => Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (context) => EditSpotScreen(spotId: doc.id, initialData: data))
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.calendar_month, color: Colors.green),
                                        tooltip: 'Manage Schedule',
                                        onPressed: () => _showScheduleEditor(doc.id, data),
                                      ),
                                      Switch(
                                        value: isMaintenance,
                                        activeThumbColor: Colors.orange,
                                        onChanged: (val) => adminService.toggleMaintenance(doc.id, val, reason: val ? "Manual maintenance" : null),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Delete Spot',
                                        onPressed: () => _confirmDelete(context, adminService, doc.id, data['name'] ?? 'Unnamed Spot'),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showScheduleEditor(String spotId, Map<String, dynamic> data) {
    // Încercăm să luăm weeklySchedule, dacă nu există, încercăm schedule (cel vechi)
    final scheduleData = data['weeklySchedule'] ?? data['schedule'];
    
    showDialog(
      context: context,
      builder: (context) => ScheduleEditorDialog(spotId: spotId, initialSchedule: scheduleData),
    );
  }

  void _confirmDelete(BuildContext context, AdminService service, String spotId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Parking Spot?"),
        content: Text("Are you sure you want to delete '$name'? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await service.deleteParkingSpot(spotId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete Permanently", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text("LIVE SYNC", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Operational Overview",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              "Real-time monitoring of $count parking assets. Any change on mobile reflects here instantly.",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () async {
            showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
            final adminService = Provider.of<AdminService>(context, listen: false);
            await adminService.checkLowRatingSuspensions();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating Audit Complete: Spots with <3.0 stars suspended.")));
            }
          },
          icon: const Icon(Icons.star_half, color: Colors.white),
          label: const Text("RATING AUDIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateSpotScreen())),
          icon: const Icon(Icons.add_location_alt, color: Colors.white),
          label: const Text("ADD NEW SPOT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData? icon;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'available':
        color = Colors.green;
        icon = Icons.wb_sunny;
        label = "SCHEDULE";
        break;
      case 'available_24_7':
        color = Colors.blue;
        icon = Icons.all_inclusive;
        label = "24/7";
        break;
      case 'offline':
        color = Colors.orange;
        icon = Icons.bedtime_outlined;
        label = "OFFLINE";
        break;
      case 'unavailable':
        color = Colors.orange;
        icon = Icons.block;
        label = "UNAVAILABLE";
        break;
      case 'low_rating':
        color = Colors.red;
        icon = Icons.star_border;
        label = "LOW RATING";
        break;
      case 'full':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
