import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Notification Monitor'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No notifications found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final type = data['type'] ?? 'unknown';
              final target = data['target'] ?? 'all';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildTypeChip(type),
                              const SizedBox(width: 8),
                              _buildRecipientChip(target),
                            ],
                          ),
                          Text(
                            createdAt != null ? DateFormat('dd MMM, HH:mm').format(createdAt) : '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(data['message'] ?? 'No Message', style: TextStyle(color: Colors.grey.shade700)),
                      
                      // EXTRA DATA FOR RESERVATIONS
                      if (type == 'reservation') ...[
                        const Divider(height: 24),
                        const Text("RESERVATION DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.person_outline, "Buyer", data['buyerName'] ?? 'N/A'),
                        _buildInfoRow(Icons.directions_car_filled_outlined, "Plate", data['carPlate'] ?? 'N/A'),
                        _buildInfoRow(Icons.access_time, "Period", "${_formatTime(data['startTime'])} - ${_formatTime(data['endTime'])}"),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRecipientChip(String target) {
    if (target == 'all') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: const Text("TO: ALL USERS", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(target).get(),
      builder: (context, snapshot) {
        String label = "TO: $target"; // Fallback to UID
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          label = "TO: ${userData['email'] ?? userData['displayName'] ?? target}";
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        );
      },
    );
  }

  Widget _buildTypeChip(String type) {
    Color color = Colors.grey;
    IconData icon = Icons.notifications;

    if (type == 'admin_announcement') {
      color = Colors.purple;
      icon = Icons.campaign;
    } else if (type == 'reservation') {
      color = Colors.blue;
      icon = Icons.book_online;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(type.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('HH:mm').format(ts.toDate());
    }
    return 'N/A';
  }
}
