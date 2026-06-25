import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ParkingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> generateInvoice(String reservationId) async {
    try {
      final resDoc = await _db.collection('reservations').doc(reservationId).get();
      if (!resDoc.exists) return;
      final resData = resDoc.data() as Map<String, dynamic>;
      
      if (resData['invoiceGenerated'] == true) return;

      final String userId = resData['userId'] ?? '';
      final double amount = (resData['totalPrice'] ?? 0).toDouble();
      
      // Fetch user name
      String userName = "Client";
      if (userId.isNotEmpty) {
        final userDoc = await _db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          userName = userDoc.data()?['displayName'] ?? "Client";
        }
      }

      final String invoiceId = "PRK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

      final invoiceData = {
        'invoiceNumber': invoiceId,
        'reservationId': reservationId,
        'userId': userId,
        'buyer': {
          'uid': userId,
          'name': userName,
        },
        'totals': {
          'totalGross': amount,
          'totalNet': amount / 1.20,
          'totalVat': amount - (amount / 1.20),
        },
        'items': [
          {
            'description': 'Servicii parcare - Rezervare #${reservationId.substring(0, 6)}',
            'unitPrice': amount,
            'quantity': 1,
          }
        ],
        'paymentStatus': 'emis',
        'createdAt': resData['createdAt'] ?? FieldValue.serverTimestamp(),
        'issuedAt': FieldValue.serverTimestamp(),
      };

      WriteBatch batch = _db.batch();
      batch.set(_db.collection('invoices').doc(), invoiceData);
      batch.update(_db.collection('reservations').doc(reservationId), {'invoiceGenerated': true});
      await batch.commit();
      
      debugPrint("Factură generată pentru rezervarea: $reservationId");
    } catch (e) {
      debugPrint("Eroare la generarea facturii: $e");
    }
  }

  Future<int> syncMissingInvoices() async {
    try {
      // Sincronizăm doar rezervările valide (excludem 'reported_occupied' care au refund 100%)
      final snapshot = await _db.collection('reservations')
          .where('status', whereIn: ['activ', 'finalizat', 'active', 'completed'])
          .get();

      int syncedCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Regula: Doar dacă nu a fost deja generată și nu este un raport de ocupare frauduloasă/eroare
        if (data['invoiceGenerated'] != true && data['status'] != 'reported_occupied') {
          await generateInvoice(doc.id);
          syncedCount++;
        }
      }
      return syncedCount;
    } catch (e) {
      debugPrint("Eroare la sincronizarea facturilor: $e");
      return 0;
    }
  }
}
