// MONITORIZARE AUDIT ȘI SECURITATE SISTEM (CERINȚA 4)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';

class SystemLogsScreen extends StatelessWidget {
  const SystemLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Security & Audit Logs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: adminService.auditLogsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Eroare: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nu există log-uri disponibile.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              final action = data['action'] ?? 'ACTION';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8)
                ),
                child: ListTile(
                  leading: _buildActionIcon(action),
                  title: Text(
                      data['details'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)
                  ),
                  subtitle: Text('By: ${data['adminEmail'] ?? 'N/A'} | Target: ${data['target'] ?? 'N/A'}'),
                  trailing: Text(
                      date != null ? DateFormat('HH:mm:ss\ndd MMM').format(date) : '...',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionIcon(String action) {
    IconData icon;
    Color color;
    switch (action) {
      case 'REFUND': icon = Icons.undo; color = Colors.orange; break;
      case 'STORNO': icon = Icons.description; color = Colors.red; break;
      case 'WALLET_CREDIT': icon = Icons.account_balance_wallet; color = Colors.green; break;
      case 'WALLET_EDIT': icon = Icons.account_balance_wallet_outlined; color = Colors.teal; break;
      case 'ROLE_CHANGE': icon = Icons.admin_panel_settings; color = Colors.indigo; break;
      case 'PRICING_CHANGE': icon = Icons.trending_up; color = Colors.blue; break;
      case 'BROADCAST': icon = Icons.campaign; color = Colors.purple; break;
      default: icon = Icons.settings; color = Colors.grey;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      radius: 18,
      child: Icon(icon, color: color, size: 18),
    );
  }
}