import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BillingCenterScreen extends StatelessWidget {
  const BillingCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centru de Facturare')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('invoices').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final invoices = snapshot.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final doc = invoices[index];
              final data = doc.data() as Map<String, dynamic>;
              final invNumber = data['invoiceNumber'] ?? 'INV-${doc.id.substring(0, 5).toUpperCase()}';
              final amount = (data['totalAmount'] ?? 0).toDouble();
              final status = data['paymentStatus'] ?? 'paid';
              final user = data['userEmail'] ?? 'User ID: ${data['userId']?.toString().substring(0,5)}';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(invNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$user\nAmount: $amount RON | Status: ${status.toUpperCase()}'),
                  isThreeLine: true,
                  trailing: TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export PDF triggered (Placeholder)'))
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('PDF'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
