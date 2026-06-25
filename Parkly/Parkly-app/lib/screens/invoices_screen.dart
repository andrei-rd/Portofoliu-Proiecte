import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/language_service.dart';
import '../services/invoice_pdf_service.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final lang = LanguageService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(lang.translate('invoices_title'),
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('buyer.uid', isEqualTo: user?.uid)
            .orderBy('issuedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Eroare la încărcare: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Nu ai nicio factură emisă încă.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            color: const Color(0xFF2563EB),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final totals = data['totals'] as Map<String, dynamic>?;
                final dynamic issuedAtData = data['issuedAt'];
                final DateTime issuedAt = issuedAtData is Timestamp 
                    ? issuedAtData.toDate() 
                    : (issuedAtData is DateTime ? issuedAtData : DateTime.now());

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['invoiceNumber'] ?? 'N/A',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                  DateFormat('dd MMM yyyy, HH:mm')
                                      .format(issuedAt),
                                  style: TextStyle(
                                      color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: data['status'] == 'emis'
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              (data['status'] == 'stornat' ? lang.translate('invoice_status_stornat') : (data['status'] ?? lang.translate('invoice_status_emis'))).toUpperCase(),
                              style: TextStyle(
                                color: data['status'] == 'emis'
                                    ? Colors.blue
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lang.translate('total_payment'),
                              style: const TextStyle(color: Colors.grey)),
                          Text(
                              '${totals?['grossTotal'] ?? totals?['totalGross'] ?? '0'} RON',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              InvoicePdfService.generateAndDownload(data),
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(lang.translate('download_pdf')),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
