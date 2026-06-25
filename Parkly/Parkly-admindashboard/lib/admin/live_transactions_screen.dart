import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'admin_service.dart';

class LiveTransactionsScreen extends StatelessWidget {
  const LiveTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Live Transactions Audit', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: adminService.liveTransactionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final transactions = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  columns: const [
                    DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('USER ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('PAID BY CLIENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('PLATFORM CUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'unknown';
                    final totalPrice = (data['totalPrice'] ?? 0).toDouble();
                    final platformEarnings = (data['platformEarnings'] ?? 0).toDouble();
                    final userId = data['userId'] ?? 'N/A';
                    final startTime = (data['startTime'] as Timestamp?)?.toDate();
                    final dateStr = startTime != null ? DateFormat('dd MMM HH:mm').format(startTime) : 'N/A';

                    return DataRow(cells: [
                      DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(doc.id.substring(0, 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(userId.length > 8 ? userId.substring(0, 8) : userId, style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${totalPrice.toStringAsFixed(2)} RON', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${platformEarnings.toStringAsFixed(2)} RON', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                      DataCell(_buildStatusChip(status)),
                      DataCell(
                        status == 'activ' 
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              onPressed: () => _confirmRefund(context, adminService, doc.id, userId, totalPrice),
                              child: const Text('Refund', style: TextStyle(color: Colors.white, fontSize: 10)),
                            )
                          : (data['refunded'] == true ? const Icon(Icons.refresh, color: Colors.green, size: 18) : const SizedBox()),
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

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'activ') color = Colors.green;
    if (status == 'anulat') color = Colors.red;
    if (status == 'finalizat') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _confirmRefund(BuildContext context, AdminService service, String resId, String userId, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Text('Are you sure you want to cancel reservation $resId and refund $amount RON to user $userId?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await service.forceRefundAndCancel(resId, userId, amount);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund processed successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Yes, Refund'),
          ),
        ],
      ),
    );
  }
}
