import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserProfileScreen({super.key, required this.userId, required this.userData});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context, listen: false);
    final isBanned = userData['isBanned'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Profil: ${userData['displayName'] ?? 'Utilizator'}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showBanDialog(context, adminService, isBanned),
              icon: Icon(isBanned ? Icons.check_circle : Icons.block, color: Colors.white),
              label: Text(isBanned ? 'ACTIVEAZĂ CONT' : 'SUSPENDĂ CONT', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBanned ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildReservationsHistory(adminService)),
                const SizedBox(width: 24),
                Expanded(child: _buildVehiclesList(adminService)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
              child: Text(
                (userData['displayName'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userData['displayName'] ?? 'Nume indisponibil', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(userData['email'] ?? 'Email indisponibil', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            _buildStatCard('Portofel Virtual', '${(userData['walletBalance'] ?? 0.0).toStringAsFixed(2)} RON', Icons.account_balance_wallet, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildReservationsHistory(AdminService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Istoric Rezervări', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: service.getUserReservations(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nicio rezervare găsită'))));

            return Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final start = (data['startTime'] as Timestamp?)?.toDate();
                  final status = data['status'] ?? 'unknown';
                  return ListTile(
                    title: Text('Rezervare #${docs[index].id.substring(0, 6)}'),
                    subtitle: Text(start != null ? DateFormat('dd MMM yyyy, HH:mm').format(start) : 'Data necunoscută'),
                    trailing: Text('${data['totalPrice']?.toStringAsFixed(2)} RON', style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: Icon(Icons.history, color: status == 'activ' ? Colors.green : Colors.grey),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVehiclesList(AdminService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mașini Înregistrate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: service.getUserVehicles(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nicio mașină înregistrată'))));

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.directions_car, color: Color(0xFF2563EB)),
                    title: Text(data['licensePlate'] ?? 'Fără număr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${data['make'] ?? ''} ${data['model'] ?? ''}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showBanDialog(BuildContext context, AdminService service, bool currentlyBanned) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentlyBanned ? 'Deblocare Cont' : 'Suspendare Cont'),
        content: Text(currentlyBanned 
          ? 'Ești sigur că vrei să deblochezi accesul acestui utilizator?' 
          : 'Utilizatorul nu va mai putea rezerva locuri sau accesa portofelul. Confirmă suspendarea.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentlyBanned ? Colors.green : Colors.red),
            onPressed: () {
              service.toggleUserBan(userId, !currentlyBanned);
              Navigator.pop(context);
              Navigator.pop(context); // Return to list
            },
            child: Text(currentlyBanned ? 'Confirmă Deblocarea' : 'Confirmă Suspendarea', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
