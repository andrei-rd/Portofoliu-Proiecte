import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'parking_service.dart';

class AdminService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ParkingService _parkingService = ParkingService();

  User? _user;
  User? get currentUser => _user;
  String? _role;
  String? get userRole => _role;

  // IMPORTANT: For production, do NOT hardcode credentials.
  // Use a secure way to manage the Server Key or OAuth token.
  // Since we are not on the Blaze plan, we use the FCM HTTP v1 API logic.
  final String _projectId = "parkly-69906";

  AdminService() {
    _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        _role = doc.data()?['role'] ?? 'user';
      } else {
        _role = null;
      }
      notifyListeners();
    });
  }

  // 1. SISTEM DE AUTENTIFICARE ȘI CONTROL ACCES ADMIN
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    // Role check is now handled in the auth listener for UI democratization
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // 2. MONITORIZARE LIVE (TRANZACȚII, FACTURI, SETĂRI)
  Stream<QuerySnapshot> get liveTransactionsStream => _db.collection('reservations').orderBy('createdAt', descending: true).snapshots();
  Stream<QuerySnapshot> get invoicesStream => _db.collection('invoices').snapshots();
  Stream<DocumentSnapshot> get pricingSettingsStream => _db.collection('settings').doc('pricing').snapshots();

  // Stream for Total Platform Profit
  Stream<double> get totalPlatformProfitStream => _db.collection('reservations')
      .snapshots()
      .map((snapshot) {
        double total = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          // REGULĂ NOUĂ: Excludem 'reported_occupied' (refund 100%) și 'anulat'
          if (['activ', 'finalizat', 'completed', 'active'].contains(status)) {
            total += (data['platformEarnings'] ?? 0).toDouble();
          }
        }
        return total;
      });

  // Detailed Profit Stream: Service Fees + Surge Pricing
  Stream<Map<String, double>> get detailedProfitStream => _db.collection('reservations')
      .snapshots()
      .map((snapshot) {
        double serviceFees = 0;
        double surgeEarnings = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          // REGULĂ NOUĂ: Excludem 'reported_occupied' (refund 100% conform politicii de raportare parcare ocupată)
          if (['activ', 'finalizat', 'completed', 'active'].contains(status)) {
            serviceFees += (data['serviceFee'] ?? 0).toDouble();
            surgeEarnings += (data['surgePricingEarnings'] ?? 0).toDouble();
          }
        }
        return {
          'serviceFees': serviceFees,
          'surgeEarnings': surgeEarnings,
          'total': serviceFees + surgeEarnings,
        };
      });

  // CERINȚA 4: Audit Logs ordonate cronologic pentru securitate
  Stream<QuerySnapshot> get auditLogsStream => _db
      .collection('audit_logs')
      .orderBy('timestamp', descending: true)
      .snapshots();

  // 3. SISTEM DE AUDIT ȘI TRASABILITATE (LOGGING)
  Future<void> _logAction(String action, String target, String details) async {
    await _db.collection('audit_logs').add({
      'action': action,
      'target': target,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'adminEmail': _user?.email ?? 'admin@parkly.ro',
    });
  }

  // 4. MANAGEMENT REZERVĂRI ȘI REFUND MANUAL/AUTOMAT
  Future<void> forceRefundAndCancel(String reservationId, String userId, double amount) async {
    try {
      final resDoc = await _db.collection('reservations').doc(reservationId).get();
      if (!resDoc.exists) return;
      final resData = resDoc.data() as Map<String, dynamic>;
      final String ownerId = resData['ownerId'] ?? '';
      final double ownerEarnings = (resData['ownerEarnings'] ?? 0).toDouble();

      WriteBatch batch = _db.batch();
      batch.update(_db.collection('reservations').doc(reservationId), {
        'status': 'anulat',
        'refunded': true,
        'cancelledBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Return money to user
      batch.update(_db.collection('users').doc(userId), {'walletBalance': FieldValue.increment(amount)});
      
      // Deduct from owner
      if (ownerId.isNotEmpty && ownerEarnings > 0) {
        batch.update(_db.collection('users').doc(ownerId), {'walletBalance': FieldValue.increment(-ownerEarnings)});
      }

      // Mark invoice as stornat if exists
      final invoiceQuery = await _db.collection('invoices').where('reservationId', isEqualTo: reservationId).get();
      for (var inv in invoiceQuery.docs) {
        batch.update(inv.reference, {'paymentStatus': 'stornat', 'stornoAt': FieldValue.serverTimestamp()});
      }

      batch.set(_db.collection('users').doc(userId).collection('notifications').doc(), {
        'title': 'Rezervare Anulată',
        'body': 'Rezervarea ta a fost anulată de administrator. $amount RON au fost returnați.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'cancellation',
      });
      await batch.commit();
      await _logAction('REFUND', reservationId, 'Refunded $amount RON to user $userId and deducted $ownerEarnings from owner $ownerId');
    } catch (e) {
      debugPrint("Error during refund: $e");
      rethrow;
    }
  }

  // Logică automată calcul Refund conform politicii Parkly (Source of Truth: 10 min window)
  double calculateAutoRefundAmount(DateTime createdAt, double amountPaid) {
    final now = DateTime.now();
    final difference = now.difference(createdAt).inMinutes;

    if (difference <= 10) return amountPaid;       // <= 10 min: 100% înapoi
    return 0.0;                                     // > 10 min: 0% înapoi (anulare fără refund)
  }

  // 5. MODUL FINANCIAR: FACTURARE ȘI STORNARE
  Future<void> stornoInvoice(String invoiceId) async {
    await _db.collection('invoices').doc(invoiceId).update({'paymentStatus': 'stornat', 'stornoAt': FieldValue.serverTimestamp()});
    await _logAction('STORNO', invoiceId, 'Stornat factura fiscala');
  }

  Future<void> createManualInvoice({
    required String userId,
    required String userName,
    required double amount,
    required List<Map<String, dynamic>> items,
  }) async {
    final String invoiceId = "PRK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    final invoiceData = {
      'invoiceNumber': invoiceId,
      'userId': userId,
      'buyer': {
        'uid': userId,
        'name': userName,
        // Optional: fetch address from user profile here
      },
      'totals': {
        'totalGross': amount,
        'totalNet': amount / 1.20,
        'totalVat': amount - (amount / 1.20),
      },
      'items': items,
      'paymentStatus': 'emis',
      'createdAt': FieldValue.serverTimestamp(),
      'issuedAt': FieldValue.serverTimestamp(), // Field requested by Admin Agent
    };

    await _db.collection('invoices').doc().set(invoiceData);
    await _logAction('INVOICE_CREATE', userId, 'Factura manuala emisa: $invoiceId ($amount RON)');
  }

  Future<void> generateInvoice(String reservationId) async {
    await _parkingService.generateInvoice(reservationId);
    await _logAction('INVOICE_SYNC', reservationId, 'Factura generata automat pentru rezervare');
  }

  Future<int> syncMissingInvoices() async {
    final syncedCount = await _parkingService.syncMissingInvoices();
    
    if (syncedCount > 0) {
       await _logAction('BULK_INVOICE_SYNC', 'all', 'Sincronizat $syncedCount facturi lipsa');
    }
    return syncedCount;
  }

  // 6. MANAGEMENT UTILIZATORI (PORTOFEL, BAN, VERIFICARE)
  Future<void> updateUserAddress(String userId, String newAddress) async {
    await _db.collection('users').doc(userId).update({'address': newAddress});
    await _logAction('USER_EDIT', userId, 'Actualizat adresa facturare');
  }

  Future<void> addWalletCredits(String userId, double amount) async {
    await _db.collection('users').doc(userId).update({'walletBalance': FieldValue.increment(amount)});
    await _logAction('WALLET_CREDIT', userId, 'Adaugat manual $amount RON');
  }

  Future<void> updateUserWalletBalance(String userId, double newBalance) async {
    await _db.collection('users').doc(userId).update({'walletBalance': newBalance});
    await _logAction('WALLET_EDIT', userId, 'Seta manual sold la $newBalance RON');
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'role': newRole});
    await _logAction('ROLE_CHANGE', userId, 'Schimbat rol in $newRole');
  }

  Future<void> toggleUserBan(String userId, bool isBanned) async {
    await _db.collection('users').doc(userId).update({
      'isBanned': isBanned,
      'bannedAt': isBanned ? FieldValue.serverTimestamp() : null,
    });
    await _logAction(isBanned ? 'USER_BAN' : 'USER_UNBAN', userId, isBanned ? 'Suspendat cont utilizator' : 'Deblocat cont utilizator');
  }

  Stream<QuerySnapshot> getUserReservations(String userId) {
    return _db.collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) // Matches the required composite index
        .snapshots();
  }

  Stream<QuerySnapshot> getUserVehicles(String userId) {
    return _db.collection('users').doc(userId).collection('vehicles').snapshots();
  }

  // 7. CERINȚA 1: DINAMIC PRICING (MODIFICARE TARIFE ORAS)
  Future<void> updatePricingSettings(Map<String, dynamic> settings) async {
    await _db.collection('settings').doc('pricing').set(settings, SetOptions(merge: true));
    await _logAction('PRICING_CHANGE', 'global', 'Modificat multiplicatori pret');
  }

  // 8. CERINȚA 2: ANALYTICS ȘI HEATMAP (ZONE SOLICITATE)
  Stream<QuerySnapshot> get heatmapAnalyticsStream => _db
      .collection('reservations')
      .where('status', isEqualTo: 'active')
      .snapshots();

  // 9. SUPORT CLIENȚI (TICKETING) ȘI BROADCAST (NOTIFICĂRI)
  Stream<QuerySnapshot> get ticketsStream => _db.collection('tickets').orderBy('updatedAt', descending: true).snapshots();

  // Stream for Reported Occupied Reservations (Decision Workflow)
  Stream<QuerySnapshot> get reportedOccupiedStream => _db.collection('reservations')
      .where('status', isEqualTo: 'reported_occupied')
      .where('refundStatus', isEqualTo: 'pending')
      .snapshots();

  Future<void> approveOccupancyRefund(String reservationId) async {
    final resDoc = await _db.collection('reservations').doc(reservationId).get();
    if (!resDoc.exists) return;
    final resData = resDoc.data() as Map<String, dynamic>;

    final String userId = resData['userId'] ?? '';
    final String parkingName = resData['parkingName'] ?? 'Parcare';
    const double guaranteeAmount = 2.0; // Fixed System Guarantee Fee

    WriteBatch batch = _db.batch();
    batch.update(_db.collection('reservations').doc(reservationId), {
      'refundStatus': 'approved',
      'guaranteeRefunded': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': 'admin',
    });

    // Refund System Guarantee (2 RON) to user
    if (userId.isNotEmpty) {
      batch.update(_db.collection('users').doc(userId), {'walletBalance': FieldValue.increment(guaranteeAmount)});
      
      // Create transaction record for history
      DocumentReference transRef = _db.collection('users').doc(userId).collection('transactions').doc();
      batch.set(transRef, {
        'amount': guaranteeAmount,
        'type': 'refund',
        'description': 'Refund Garanție Sistem',
        'timestamp': FieldValue.serverTimestamp(),
        'reservationId': reservationId,
      });

      batch.set(_db.collection('users').doc(userId).collection('notifications').doc(), {
        'title': 'Decizie Suport',
        'body': 'Raport aprobat! Suma a fost returnată în portofelul tău.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'wallet_update',
      });
    }

    await batch.commit();
    await _logAction('OCCUPANCY_GUARANTEE_REFUND', reservationId, 'Approved 2 RON guarantee refund for user $userId.');
  }

  Future<void> rejectOccupancyReport(String reservationId) async {
    final resDoc = await _db.collection('reservations').doc(reservationId).get();
    if (!resDoc.exists) return;
    final resData = resDoc.data() as Map<String, dynamic>;
    final String userId = resData['userId'] ?? '';

    await _db.collection('reservations').doc(reservationId).update({
      'refundStatus': 'rejected',
      'status': 'activ',
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': 'admin',
    });

    if (userId.isNotEmpty) {
      await _db.collection('users').doc(userId).collection('notifications').add({
        'title': 'Decizie Suport',
        'body': 'Raportarea a fost respinsă din lipsă de dovezi concludente. Rezervarea rămâne validă.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'info',
      });
    }

    await _logAction('OCCUPANCY_REPORT_REJECT', reservationId, 'Rejected occupancy report.');
  }

  Stream<QuerySnapshot> getTicketMessagesStream(String ticketId) {
    return _db.collection('tickets').doc(ticketId).collection('messages').orderBy('timestamp', descending: true).snapshots();
  }

  Future<String> uploadChatImage(String ticketId, Uint8List fileBytes) async {
    final fileName = "chat_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final ref = _storage.ref().child('tickets/$ticketId/$fileName');
    final uploadTask = await ref.putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'));
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> replyToTicket(String ticketId, String message, {String? imageUrl}) async {
    await _db.collection('tickets').doc(ticketId).update({
      'status': 'responded',
      'lastReply': imageUrl != null ? '[Imagine]' : message,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    Map<String, dynamic> messageData = {
      'text': message,
      'sender': 'admin',
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (imageUrl != null) {
      messageData['imageUrl'] = imageUrl;
    }

    await _db.collection('tickets').doc(ticketId).collection('messages').add(messageData);

    await _logAction('TICKET_REPLY', ticketId, 'Trimis răspuns la tichet suport ${imageUrl != null ? "(cu imagine)" : ""}');
  }

  Future<void> sendBroadcast({
    required String title,
    required String message,
    required String target,
    required bool sendPush,
    required bool sendEmail,
  }) async {
    List<String> tokens = [];
    List<String> emails = [];

    // 1. Identificăm destinatarii (Tokens și Emails)
    Query query = _db.collection('users');
    if (target == 'owners') query = query.where('role', isEqualTo: 'owner');

    final snapshot = await query.get();
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      if (sendPush) {
        final token = data['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) tokens.add(token);
      }
      
      if (sendEmail) {
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) emails.add(email);
      }
    }

    // 2. Trimitere Push via FCM
    if (sendPush && tokens.isNotEmpty) {
      debugPrint("Sending campaign to ${tokens.length} tokens via FCM HTTP v1...");
      for (String token in tokens) {
        await _sendIndividualNotification(token, title, message);
      }
    }

    // 3. Declanșare Email via Firebase Extension (Colecția 'mail')
    if (sendEmail && emails.isNotEmpty) {
      debugPrint("Queueing ${emails.length} emails via Firebase Trigger Email Extension...");
      WriteBatch emailBatch = _db.batch();
      for (String email in emails) {
        DocumentReference mailRef = _db.collection('mail').doc();
        emailBatch.set(mailRef, {
          'to': email,
          'message': {
            'subject': title,
            'text': message,
            'html': "<div style='font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;'>"
                    "<h2>$title</h2>"
                    "<p>$message</p>"
                    "<hr/>"
                    "<p style='font-size: 12px; color: #888;'>Primit via Parkly Admin Dashboard</p>"
                    "</div>",
          },
        });
      }
      await emailBatch.commit();
    }

    // 4. Salvare în colecția 'notifications' pentru Inbox-ul mobil
    await _db.collection('notifications').add({
      'title': title,
      'message': message,
      'type': 'admin_announcement',
      'target': target,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await _db.collection('broadcasts').add({
      'title': title,
      'message': message,
      'target': target,
      'tokenCount': tokens.length,
      'emailCount': emails.length,
      'channels': {'push': sendPush, 'email': sendEmail},
      'status': 'sent',
      'sentAt': FieldValue.serverTimestamp(),
    });

    await _logAction('BROADCAST', target, 'Campanie lansata: ${tokens.length} Push, ${emails.length} Email.');
  }

  // Logică FCM HTTP v1
  Future<void> _sendIndividualNotification(String token, String title, String body) async {
    try {
      final String accessToken = "YOUR_ACCESS_TOKEN_HERE"; // Needs to be generated dynamically

      final url = Uri.parse("https://fcm.googleapis.com/v1/projects/$_projectId/messages:send");

      final payload = {
        "message": {
          "token": token,
          "notification": {
            "title": title,
            "body": body
          },
          "android": {
            "priority": "high"
          },
          "data": {
            "type": "broadcast"
          }
        }
      };

      await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $accessToken"
          },
          body: jsonEncode(payload)
      );
    } catch (e) {
      debugPrint("Individual Push Error: $e");
    }
  }

  // 10. ASSET CONTROL (PARKING SPOTS)
  // REGULĂ NOUĂ 4: Suspendare Automată Rating Scăzut
  Future<void> checkLowRatingSuspensions() async {
    final snapshot = await _db.collection('parking_spaces').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final double avgRating = (data['avgRating'] ?? 5.0).toDouble();
      final int totalReviews = (data['totalReviews'] ?? 0).toInt();

      if (totalReviews >= 3 && avgRating < 3.0) {
        if (data['isUnderMaintenance'] != true) {
          await toggleMaintenance(doc.id, true, reason: "Low Rating ($avgRating stele)");
        }
      }
    }
  }

  Future<void> toggleMaintenance(String spotId, bool isUnavailable, {String? reason}) async {
    await _db.collection('parking_spaces').doc(spotId).update({
      'status': isUnavailable ? 'unavailable' : 'available',
      'isUnderMaintenance': isUnavailable,
      'maintenanceReason': isUnavailable ? (reason ?? 'Manual intervention') : null,
      'lastStatusChange': FieldValue.serverTimestamp(),
    });
    await _logAction('SPOT_STATUS', spotId, 'Set to ${isUnavailable ? 'UNAVAILABLE' : 'AVAILABLE'} | Reason: ${reason ?? 'N/A'}');
  }

  Future<void> deleteParkingSpot(String spotId) async {
    await _db.collection('parking_spaces').doc(spotId).delete();
    await _logAction('SPOT_DELETE', spotId, 'Deleted parking spot');
  }

  bool hasOverlap(DateTime startA, DateTime endA, DateTime startB, DateTime endB) {
    return startA.isBefore(endB) && endA.isAfter(startB);
  }
}