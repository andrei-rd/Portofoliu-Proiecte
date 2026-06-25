
// MANAGEMENT REZERVĂRI ȘI CALCUL REFUND AUTOMAT (CERINȚA 3)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'admin_service.dart';

class ManageReservationsScreen extends StatelessWidget {
  const ManageReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final adminService = Provider.of<AdminService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations Management'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('reservations').orderBy('startTime', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final reservations = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Total Price')),
                    DataColumn(label: Text('Start Time')),
                    DataColumn(label: Text('User ID')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: reservations.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final start = (data['startTime'] as Timestamp?)?.toDate();
                    final format = DateFormat('dd/MM HH:mm');
                    final userId = data['userId']?.toString() ?? 'N/A';
                    final amount = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] ?? 'unknown';

                    return DataRow(cells: [
                      DataCell(_buildStatusChip(status)),
                      DataCell(Text('${amount.toStringAsFixed(2)} RON', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(start != null ? format.format(start) : 'N/A')),
                      DataCell(Text(userId.length > 8 ? userId.substring(0, 8) : userId)),
                      DataCell(
                        ElevatedButton(
                          onPressed: () => _showReservationDetails(context, adminService, doc.id, userId, start, amount, data),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                          child: const Text("Detalii"),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReservationDetails(BuildContext context, AdminService service, String resId, String userId, DateTime? start, double amount, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Detalii Rezervare #${resId.substring(0,6)}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow("Loc:", data['parkingName'] ?? 'N/A'),
            _buildInfoRow("Utilizator:", data['userEmail'] ?? userId),
            _buildInfoRow("Plăcuță:", data['carPlate'] ?? 'N/A'),
            _buildInfoRow("Status:", data['status']?.toString().toUpperCase() ?? 'N/A'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: data['status'] == 'anulat' ? null : () {
                  Navigator.pop(ctx);
                  _showRefundDialog(context, service, resId, userId, start, amount, data);
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text("Anulează Rezervarea (Refund Manual)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Acțiunile de 'Prelungire' sau 'Raportare' sunt rezervate utilizatorilor din aplicația mobilă.", 
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  void _showReportOccupiedInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Raportare Loc Ocupat"),
        content: const Text(
          "Dacă raportezi locul ocupat, vei primi imediat refund pentru suma parcării, dar taxa de 2 RON va fi reținută ca garanție.\n\n"
          "Dacă echipa de suport confirmă raportarea ta pe baza pozei trimise, vei primi înapoi și cei 2 RON.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ÎNCHIDE")),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // LOGICĂ DIALOG REFUND: CALCULEAZĂ SUMA BAZAT PE TIMPUL RĂMAS
  void _showRefundDialog(BuildContext context, AdminService service, String resId, String userId, DateTime? start, double amount, Map<String, dynamic> data) {
    if (start == null) return;

    // Calculăm timpul rămas până la începere
    final now = DateTime.now();
    final difference = start.difference(now).inMinutes;

    double refundAmount;
    String policyNote;

    // Aplicăm politica cerută
    if (data['status'] == 'reported_occupied') {
       refundAmount = amount;
       policyNote = "Refund 100% - Loc Ocupat Raportat (Dovadă Foto)";
    } else if (difference >= 60) {
      refundAmount = amount; // 100% refund
      policyNote = "Refund Integral (peste 60 min rămase)";
    } else if (difference >= 10) {
      refundAmount = amount * 0.5; // 50% refund
      policyNote = "Refund Parțial 50% (între 10-60 min rămase)";
    } else {
      refundAmount = 0.0; // 0% refund
      policyNote = "Fără Refund (mai puțin de 10 min rămase)";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmă Anulare & Refund"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['status'] == 'reported_occupied') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text("LOC OCUPAT raportat. Refund-ul de 100% este politică Parkly.", style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              if (data['evidenceUrl'] != null)
                 Padding(
                   padding: const EdgeInsets.only(bottom: 16.0),
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: Image.network(data['evidenceUrl'], height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Text("Eroare încărcare dovadă foto")),
                   ),
                 ),
            ],
            Text("Sumă plătită: $amount RON"),
            const SizedBox(height: 8),
            Text("Politică aplicată: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            Text(policyNote),
            const Divider(),
            Text(
              "Suma de returnat: ${refundAmount.toStringAsFixed(2)} RON",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("RENUNȚĂ")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await service.forceRefundAndCancel(resId, userId, refundAmount);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Rezervare anulată. Refund: $refundAmount RON")),
                  );
                }
              },
              child: const Text("CONFIRMĂ ANULAREA", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  // UI: CHIP-URI STATUS COLORATE
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'activ': color = Colors.green; break;
      case 'anulat': color = Colors.red; break;
      case 'reported_occupied': color = Colors.orange; break;
      case 'completat': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}