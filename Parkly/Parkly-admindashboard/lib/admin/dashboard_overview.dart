import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_reservations_screen.dart';

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Overview')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Statistics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatCard(
                  context,
                  'Total Users',
                  firestore.collection('users').snapshots(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  context,
                  'Parking Spaces',
                  firestore.collection('parking_spaces').snapshots(),
                  Icons.local_parking,
                  Colors.green,
                ),
                // 2. ACEST CARD ARE ACUM FUNCȚIA DE CLICK (onTap)
                _buildStatCard(
                  context,
                  'Total Reservations',
                  firestore.collection('reservations').snapshots(),
                  Icons.receipt_long,
                  Colors.orange,
                  onTap: () {
                    // Aceasta este comanda care deschide ecranul cerut
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ManageReservationsScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Sfat: Apasă pe cardul portocaliu pentru a gestiona Refund-ul.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      String title,
      Stream<QuerySnapshot> stream,
      IconData icon,
      Color color, {
        VoidCallback? onTap, // Am adăugat opțiunea de click
      }) {
    return Expanded(
      child: InkWell( // InkWell face cardul să fie clicabil
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            String value = '...';
            if (snapshot.hasData && snapshot.data != null) {
              value = snapshot.data!.docs.length.toString();
            }

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(icon, size: 40, color: color),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}