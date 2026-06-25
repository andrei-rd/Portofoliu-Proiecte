import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/parking_space.dart';
import 'notification_service.dart';
import 'language_service.dart';

import '../utils/app_exception.dart';

import 'config_service.dart';

class PriceDetails {
  final double finalPrice;
  final double basePriceTotal;
  final double ownerEarnings;
  final double platformEarnings;
  final double serviceFee; // Taxă de sistem fixă
  final List<String> reasons;
  PriceDetails({
    required this.finalPrice,
    required this.basePriceTotal,
    required this.ownerEarnings,
    required this.platformEarnings,
    required this.serviceFee,
    required this.reasons,
  });
}

class ParkingService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final NotificationService _notifService = NotificationService();

  ParkingService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<List<ParkingSpace>> getParkingSpaces() {
    return _db
        .collection('parking_spaces')
        .snapshots()
        .asyncMap((snapshot) async {
      // Fetch active reservations to determine real-time availability
      final resSnapshot = await _db
          .collection('reservations')
          .where('status', isEqualTo: 'activ')
          .get();

      final now = DateTime.now();
      final activeSpotIds = resSnapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              if (!data.containsKey('spotId') || data['spotId'] == null) {
                return null;
              }

              final Timestamp? endTs = data['endTime'] as Timestamp?;
              if (endTs == null) {
                return data['spotId'] as String; // Fără timp = ocupat permanent
              }

              final DateTime end = endTs.toDate();
              return end.isAfter(now) ? data['spotId'] as String : null;
            } catch (e) {
              return null; // Document corupt, îl ignorăm
            }
          })
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      Map<String, List<DocumentSnapshot>> grouped = {};

      for (var doc in snapshot.docs) {
        String key = (doc['name'] ?? '') + (doc['address'] ?? '');
        if (!grouped.containsKey(key)) grouped[key] = [];
        grouped[key]!.add(doc);
      }

      return grouped.entries.map((entry) {
        final first = entry.value.first.data() as Map<String, dynamic>;

        int total = first['totalSpots'] ?? entry.value.length;

        // Un loc este considerat disponibil dacă:
        // 1. Nu este în mentenanță
        // 2. NU are o rezervare activă (endTime în viitor)
        // 3. Este în programul de funcționare (verificat în UI și la rezervare,
        //    dar aici calculăm numărul pentru afișare)
        int available = entry.value.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final schedule = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
          
          final bool isAlways = schedule['isAlwaysAvailable'] == true;
          final bool isManuallyDisabled = schedule['isManuallyDisabled'] == true;
          final bool underMaintenance = data['isUnderMaintenance'] == true || 
                                      data['status'] == 'MAINTENANCE';
          
          // 1. Dacă este dezactivat manual sau în mentenanță, e INDISPONIBIL
          if (isManuallyDisabled || underMaintenance) return false;

          // 2. Dacă NU este AlwaysAvailable, verificăm programul orar curent
          if (!isAlways) {
            final now = DateTime.now();
            final dayName = _getDayName(now.weekday);
            final daySched = schedule[dayName];

            if (daySched == null || daySched['active'] == false) return false;

            try {
              final String startTimeStr = daySched['start'] ?? '00:00';
              final String endTimeStr = daySched['end'] ?? '23:59';
              final startParts = startTimeStr.split(':');
              final endParts = endTimeStr.split(':');

              final startHour = int.parse(startParts[0]);
              final startMin = int.parse(startParts[1]);
              final endHour = int.parse(endParts[0]);
              final endMin = int.parse(endParts[1]);

              final schedStart = DateTime(now.year, now.month, now.day, startHour, startMin);
              DateTime schedEnd = DateTime(now.year, now.month, now.day, endHour, endMin);

              if (schedEnd.isBefore(schedStart)) {
                schedEnd = schedEnd.add(const Duration(days: 1));
              }

              if (now.isBefore(schedStart) || now.isAfter(schedEnd)) {
                return false; // Închis conform orarului
              }
            } catch (e) {
              // Dacă e eroare de parsing, considerăm deschis pt siguranță
            }
          }

          // 3. Dacă are o rezervare activă, e OCUPAT
          final bool isCurrentlyReserved = activeSpotIds.contains(doc.id);
          if (isCurrentlyReserved) return false;
          
          return true;
        }).length;

        List<String> docIds = entry.value.map((doc) => doc.id).toList();

        List<String> imageUrls = [];
        if (first['imageUrls'] != null) {
          imageUrls = List<String>.from(first['imageUrls']);
        } else if (first['imageUrl'] != null &&
            first['imageUrl'] != 'https://via.placeholder.com/150') {
          imageUrls = [first['imageUrl']];
        }

        // Grupul este în mentenanță dacă ORICARE document din el are flag-ul setat (robust)
        bool groupUnderMaintenance = entry.value.any((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final mVal = data['isUnderMaintenance'];
          final sVal = data['status'];
          final maintVal = data['maintenance'];

          return mVal == true ||
              mVal == 'true' ||
              sVal == 'MAINTENANCE' ||
              sVal == 'maintenance' ||
              maintVal == true ||
              maintVal == 'true';
        });

        Map<String, dynamic> schedule = {};
        if (first['weeklySchedule'] != null) {
          try {
            schedule = Map<String, dynamic>.from(first['weeklySchedule']);
          } catch (e) {
            if (kDebugMode) print("Eroare parsing schedule: $e");
          }
        }

        return ParkingSpace(
          id: entry.value.first.id,
          docIds: docIds,
          ownerId: first['ownerId'] ?? '',
          ownerName: first['ownerName'] ?? 'Admin',
          ownerUsername: first['ownerUsername'] ?? '',
          name: first['name'] ?? '',
          address: first['address'] ?? '',
          latitude: (first['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (first['longitude'] as num?)?.toDouble() ?? 0.0,
          pricePerHour: (first['pricePerHour'] as num?)?.toDouble() ?? 0.0,
          totalSpots: total,
          availableSpots: available,
          imageUrl: first['imageUrl'] ?? 'https://via.placeholder.com/150',
          imageUrls: imageUrls,
          isUnderMaintenance: groupUnderMaintenance,
          description: first['description'] ?? '',
          weeklySchedule: schedule,
          spotNumber: first['spotNumber'] ?? '',
          facilities: List<String>.from(first['facilities'] ?? []),
        );
      }).toList();
    });
  }

  Future<void> addSingleSpot(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    String ownerName = user?.displayName ?? 'Admin';
    String ownerUsername = '';

    if (user != null) {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        ownerName = userData['displayName'] ?? user.displayName ?? 'Proprietar';
        ownerUsername = userData['username'] ?? '';
      }
    }

    int count = data['totalSpots'] ?? 1;
    final batch = _db.batch();

    for (int i = 0; i < count; i++) {
      final docRef = _db.collection('parking_spaces').doc();
      batch.set(docRef, {
        ...data,
        'weeklySchedule': {
          ...data['weeklySchedule'],
          'isManuallyDisabled': false,
          'isAlwaysAvailable': false,
        },
        'ownerId': user?.uid ?? '',
        'ownerName': ownerName,
        'ownerUsername': ownerUsername,
        'location': GeoPoint(data['latitude'], data['longitude']),
        'totalSpots': 1,
        'availableSpots': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateSingleSpot(String id, Map<String, dynamic> data,
      {List<String>? allDocIds}) async {
    final batch = _db.batch();
    final idsToUpdate = allDocIds ?? [id];

    for (var docId in idsToUpdate) {
      batch.update(_db.collection('parking_spaces').doc(docId), {
        ...data,
        'location': GeoPoint(data['latitude'], data['longitude']),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalSpots': 1, // Keep individual doc as 1 spot
        // Note: we don't force availableSpots to 1 here to avoid resetting current occupancy
      });
    }
    await batch.commit();
  }

  Future<void> setParkingState(List<String> docIds, String state) async {
    final batch = _db.batch();
    for (var id in docIds) {
      final docRef = _db.collection('parking_spaces').doc(id);
      /* bool isAvailableValue = true; */
      
      Map<String, dynamic> updates = {};
      
      if (state == 'deactivated') {
        /* isAvailableValue = false; */
        updates = {
          'weeklySchedule.isManuallyDisabled': true,
          'weeklySchedule.isAlwaysAvailable': false,
          'isAvailable': false,
        };
      } else if (state == 'schedule') {
        // Aici isAvailable depinde de orar, dar îl setăm true pentru a fi procesat de stream-ul din Dashboard
        updates = {
          'weeklySchedule.isManuallyDisabled': false,
          'weeklySchedule.isAlwaysAvailable': false,
          'isAvailable': true,
        };
      } else if (state == '24/7') {
        updates = {
          'weeklySchedule.isManuallyDisabled': false,
          'weeklySchedule.isAlwaysAvailable': true,
          'isAvailable': true,
        };
      }
      
      batch.update(docRef, updates);
    }
    await batch.commit();
  }

  Future<void> deleteSpot(String id) async {
    await _db.collection('parking_spaces').doc(id).delete();
  }

  Future<Map<String, dynamic>> reserveSpot(ParkingSpace space, double price,
      {DateTime? startTime, DateTime? endTime, String? carPlate}) async {
    final lang = LanguageService();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Neautentificat");
    }
    if (carPlate == null || carPlate.isEmpty) {
      throw Exception("Numărul de înmatriculare este obligatoriu!");
    }

    // Default to "now" if no start/end provided
    final start = startTime ?? DateTime.now();
    final end = endTime ?? start.add(const Duration(hours: 1));

    // VALIDARE ORA DIN TRECUT
    if (start.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      throw Exception(lang.translate('past_time_error'));
    }

    // VERIFICARE PROGRAM (Custom Schedule)
    if (!_isWithinSchedule(space, start, end)) {
      final dayName = _getDayName(start.weekday);
      final daySched = space.weeklySchedule[dayName];
      String interval = lang.currentLocale.languageCode == 'ro' ? "închis" : "closed";
      if (daySched != null && daySched['active'] == true) {
        interval = lang.currentLocale.languageCode == 'ro' 
          ? "între ${daySched['start']} și ${daySched['end']}"
          : "between ${daySched['start']} and ${daySched['end']}";
      }
      
      if (lang.currentLocale.languageCode == 'ro') {
        throw Exception("Ne pare rău! Pentru ziua de $dayName, această parcare este disponibilă $interval.");
      } else {
        throw Exception("Sorry! For $dayName, this parking is available $interval.");
      }
    }

    // Calculate final price based on dynamic rules
    final priceDetails = getPriceDetails(space, start, end);
    final double finalPrice = priceDetails.finalPrice;
    final double ownerEarnings = priceDetails.ownerEarnings;
    final double platformEarnings = priceDetails.platformEarnings;

    Map<String, dynamic> reservationData = {};
    String resId = "";

    try {
      // 1. RESTRICȚIE PROPRIETAR
      if (space.ownerId == user.uid) {
        throw Exception(lang.currentLocale.languageCode == 'ro'
            ? "Nu poți rezerva propriul tău loc de parcare!"
            : "You cannot reserve your own parking spot!");
      }

      // 2. VERIFICARE LIMITĂ REZERVĂRI ACTIVE (MAX 5 PER UTILIZATOR)
      final activeUserRes = await _db
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'activ')
          .get();

      // Numărăm doar rezervările care nu au expirat încă
      final now = DateTime.now();
      int realActiveCount = activeUserRes.docs.where((doc) {
        final data = doc.data();
        final Timestamp? endTs = data['endTime'] as Timestamp?;
        if (endTs == null) return true; // Fără timp = activ permanent
        return endTs.toDate().isAfter(now);
      }).length;

      if (realActiveCount >= 5) {
        throw Exception("Ai atins limita maximă de 5 rezervări active simultan!");
      }

      // 3. VERIFICARE CONFLICT MAȘINĂ (MAX 2 REZERVĂRI SUPRAPUSE PER PLĂCUȚĂ)
      // Permitem 2 pentru flexibilitate (ex: una expiră, alta începe), dar nu 3.
      final carPlateConflict = await _db
          .collection('reservations')
          .where('carPlate', isEqualTo: carPlate)
          .where('status', isEqualTo: 'activ')
          .get();

      int overlaps = 0;
      for (var doc in carPlateConflict.docs) {
        final d = doc.data();
        final DateTime eStart = (d['startTime'] as Timestamp).toDate();
        final DateTime eEnd = (d['endTime'] as Timestamp).toDate();
        if (start.isBefore(eEnd) && end.isAfter(eStart)) {
          overlaps++;
        }
      }
      if (overlaps >= 2) {
        throw Exception(lang.currentLocale.languageCode == 'ro'
            ? "Această mașină are deja 2 rezervări active în acest interval!"
            : "This car already has 2 active reservations in this interval!");
      }

      // Căutăm primul ID de document din grup care nu are conflict de rezervare
      String? availableDocId;
      for (String docId in space.docIds) {
        // Verificăm dacă spot-ul individual este marcat manual ca indisponibil sau mentenanță
        final spotDoc = await _db.collection('parking_spaces').doc(docId).get();
        if (!spotDoc.exists) continue;
        
        final data = spotDoc.data() as Map<String, dynamic>;
        final schedule = data['weeklySchedule'] as Map<String, dynamic>? ?? {};
        final bool isManuallyDisabled = schedule['isManuallyDisabled'] == true;
        final bool underMaintenance = data['isUnderMaintenance'] == true || 
                                     data['status'] == 'MAINTENANCE';
        
        if (isManuallyDisabled || underMaintenance) continue;

        // Verificăm dacă există deja o rezervare suprapusă pe acest loc specific
        bool overlap = await hasOverlap(docId, start, end);
        if (!overlap) {
          availableDocId = docId;
          break;
        }
      }

      if (availableDocId == null) throw Exception(lang.translate('no_spots_error'));

      await _db.runTransaction((transaction) async {
        DocumentReference userRef = _db.collection('users').doc(user.uid);
        DocumentSnapshot userSnap = await transaction.get(userRef);

        double currentBalance = 0.0;
        Map<String, dynamic> userData = {};
        if (userSnap.exists) {
          userData = userSnap.data() as Map<String, dynamic>;
          currentBalance = (userData['walletBalance'] ?? 0).toDouble();
        }

        if (currentBalance < finalPrice + 5.0) {
          throw Exception(lang.currentLocale.languageCode == 'ro'
              ? "Fonduri insuficiente! Trebuie să ai minim ${finalPrice + 5} RON (inclusiv buffer de 5 RON)."
              : "Insufficient funds! You must have at least ${finalPrice + 5} RON (including 5 RON buffer).");
        }

        /* DocumentReference spotRef =
            _db.collection('parking_spaces').doc(availableDocId); */
        DocumentReference resRef = _db.collection('reservations').doc();
        resId = resRef.id;

        transaction
            .update(userRef, {'walletBalance': currentBalance - finalPrice});
        
        // Nu mai scădem manual availableSpots deoarece folosim verificarea de conflict (hasOverlap)
        // care este mult mai precisă pentru rezervări viitoare.

        // 2. PLĂTIM PROPRIETARUL (Dacă există)
        if (space.ownerId.isNotEmpty && space.ownerId != user.uid) {
          DocumentReference ownerRef = _db.collection('users').doc(space.ownerId);
          transaction.update(ownerRef, {
            'walletBalance': FieldValue.increment(ownerEarnings),
          });

          // Tranzacție credit pentru proprietar (Sub-colecție)
          final String ownerTransTitle = '${lang.translate('trans_rental_income')}: ${space.name} (Loc: ${space.spotNumber})';
          transaction.set(_db.collection('users').doc(space.ownerId).collection('transactions').doc(), {
            'title': ownerTransTitle,
            'amount': ownerEarnings,
            'type': 'rental_income',
            'timestamp': FieldValue.serverTimestamp(),
          });

            // Notificare credit pentru proprietar
          DocumentReference ownerCreditNotifRef = _db.collection('notifications').doc();
          transaction.set(ownerCreditNotifRef, {
            'target': space.ownerId,
            'title': '💰 Bani primiți în portofel',
            'message': lang.currentLocale.languageCode == 'ro' 
                ? 'Ai primit $ownerEarnings RON pentru închirierea locului tău ${space.spotNumber}.'
                : 'You received $ownerEarnings RON for renting your spot ${space.spotNumber}.',
            'type': 'payment',
            'isRead': false,
            'showPopup': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Log transaction (Full payment) (Sub-colecție)
        final String userTransTitle = '${lang.currentLocale.languageCode == 'ro' ? 'Plată parcare' : 'Parking payment'}: ${space.name}';
        transaction.set(_db.collection('users').doc(user.uid).collection('transactions').doc(), {
          'title': userTransTitle,
          'amount': -finalPrice,
          'type': 'payment',
          'timestamp': FieldValue.serverTimestamp(),
        });

        reservationData = {
          'userId': user.uid,
          'spotId': availableDocId,
          'parkingName': space.name,
          'carPlate': carPlate, // SALVĂM NR ÎNMATRICULARE
          'latitude': space.latitude,
          'longitude': space.longitude,
          'startTime': Timestamp.fromDate(start),
          'endTime': Timestamp.fromDate(end),
          'createdAt': FieldValue.serverTimestamp(),
          'totalPrice': finalPrice,
          'serviceFee': priceDetails.serviceFee,
          'ownerEarnings': ownerEarnings,
          'platformEarnings': platformEarnings,
          'status': 'activ',
          'invoiceGenerated': false,
        };

        transaction.set(resRef, reservationData);

        // 3. NOTIFICARE PENTRU UTILIZATOR (BUYER)
        final String spotDisplay = space.spotNumber.isNotEmpty ? "locul ${space.spotNumber}" : "un loc";
        DocumentReference userNotifRef = _db.collection('notifications').doc();
        transaction.set(userNotifRef, {
          'target': user.uid,
          'title': '✅ Rezervare Confirmată',
          'message': lang.currentLocale.languageCode == 'ro'
              ? 'Ai rezervat $spotDisplay la ${space.name}.'
              : 'You reserved ${space.spotNumber.isNotEmpty ? "spot ${space.spotNumber}" : "a spot"} at ${space.name}.',
          'type': 'reservation',
          'spotId': space.id, // Adăugăm spotId pentru a afișa cardul în notificări
          'carPlate': carPlate,
          'startTime': Timestamp.fromDate(start),
          'endTime': Timestamp.fromDate(end),
          'isRead': false,
          'showPopup': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. NOTIFICARE PENTRU PROPRIETAR (OWNER)
        if (space.ownerId.isNotEmpty && space.ownerId != user.uid) {
          DocumentReference ownerNotifRef =
              _db.collection('notifications').doc();
          transaction.set(ownerNotifRef, {
            'target': space.ownerId,
            'title': '🅿️ Loc Închiriat',
            'message': lang.currentLocale.languageCode == 'ro'
                ? 'Utilizatorul ${userData['displayName'] ?? "Client"} a închiriat locul tău (${space.name}) cu mașina $carPlate.'
                : 'User ${userData['displayName'] ?? "Client"} rented your spot (${space.name}) with car $carPlate.',
            'type': 'reservation',
            'spotId': space.id, // Adăugăm spotId
            'buyerId': user.uid,
            'buyerName': userData['displayName'],
            'buyerEmail': userData['email'],
            'buyerPhotoURL': userData['photoURL'],
            'carPlate': carPlate,
            'startTime': Timestamp.fromDate(start),
            'endTime': Timestamp.fromDate(end),
            'isRead': false,
            'showPopup': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 4. Programăm reminderele memento (5m și 1m înainte)
      if (resId.isNotEmpty) {
        await _notifService.scheduleExpiryReminders(resId, space.name, end);
        // Auto-generăm factura imediat după succesul rezervării
        await generateInvoice(resId);
      }

      return {
        'id': resId,
        'data': reservationData,
      };
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> repostAllInGroup(List<String> docIds) async {
    for (var id in docIds) {
      if (await _hasActiveReservation(id)) {
        throw AppException(
            "Nu poți reposta! Există o rezervare activă pe acest loc.",
            code: 'active-reservation');
      }
    }

    final batch = _db.batch();
    for (var id in docIds) {
      batch.update(
          _db.collection('parking_spaces').doc(id), {'availableSpots': 1});
    }
    await batch.commit();
  }

  Future<bool> _hasActiveReservation(String spotId) async {
    final query = await _db
        .collection('reservations')
        .where('spotId', isEqualTo: spotId)
        .where('status', isEqualTo: 'activ')
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      final DateTime endTime = (data['endTime'] as Timestamp).toDate();
      if (endTime.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  Future<void> unpostAllInGroup(List<String> docIds) async {
    final batch = _db.batch();
    for (var id in docIds) {
      batch.update(
          _db.collection('parking_spaces').doc(id), {'availableSpots': 0});
    }
    await batch.commit();
  }

  // ADVANCED INVOICE GENERATION
  Future<void> generateInvoice(String reservationId) async {
    try {
      // 0. VERIFICARE IDEMPOTENȚĂ (Să nu generăm duplicate)
      final existingInvoice = await _db.collection('invoices')
          .where('reservationId', isEqualTo: reservationId)
          .limit(1)
          .get();
      
      if (existingInvoice.docs.isNotEmpty) {
        await _db.collection('reservations').doc(reservationId).update({'invoiceGenerated': true});
        return;
      }

      DocumentSnapshot resSnap =
          await _db.collection('reservations').doc(reservationId).get();
      if (!resSnap.exists) return;

      final data = resSnap.data() as Map<String, dynamic>;
      
      // Fetch Buyer Info
      final userSnap = await _db.collection('users').doc(data['userId']).get();
      final userData = userSnap.data() as Map<String, dynamic>? ?? {};

      // Fetch Spot & Owner Info
      final spotSnap = await _db.collection('parking_spaces').doc(data['spotId']).get();
      final spotData = spotSnap.exists ? (spotSnap.data() as Map<String, dynamic>) : {};
      final String ownerId = spotData['ownerId'] ?? '';
      
      // Fetch Full Owner Data from users collection
      final ownerSnap = ownerId.isNotEmpty ? await _db.collection('users').doc(ownerId).get() : null;
      final ownerUserData = (ownerSnap != null && ownerSnap.exists) ? (ownerSnap.data() as Map<String, dynamic>) : {};
      
      final String ownerName = ownerUserData['displayName'] ?? spotData['ownerName'] ?? 'Proprietar Parkly';

      double totalAmount = (data['totalPrice'] ?? 0.0).toDouble();
      double tvaRate = 0.20; // 20% TVA
      double netAmount = totalAmount / (1 + tvaRate);
      double tvaAmount = totalAmount - netAmount;

      // Map unique invoice details
      await _db.collection('invoices').add({
        'invoiceNumber':
            'PRK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        'reservationId': reservationId,
        'issuedAt': FieldValue.serverTimestamp(),
        'status': 'emis',
        'ownerId': ownerId,

        // Buyer Info (Client)
        'buyer': {
          'uid': data['userId'],
          'name': userData['displayName'] ?? userData['name'] ?? 'Client Parkly',
          'email': userData['email'] ?? 'Nespecificat',
          'phone': userData['phone'] ?? userData['phoneNumber'] ?? 'Nespecificat',
          'address': userData['address'] ?? '', // Dacă e gol, nu afișăm nimic
        },

        // Platform Seller
        'seller': {
          'name': 'PARKLY APP SRL',
          'cif': 'RO48291022',
          'regCom': 'J40/9921/2023',
          'address': 'Bucuresti, Sector 1',
          'email': 'billing@parkly.ro',
        },
        
        // Detailed Service Info (Owner)
        'provider': {
          'name': ownerName,
          'email': ownerUserData['email'] ?? 'Nespecificat',
          'phone': ownerUserData['phone'] ?? ownerUserData['phoneNumber'] ?? 'Nespecificat',
          'parkingName': data['parkingName'],
          'spotNumber': spotData['spotNumber'] ?? 'N/A',
        },

        // Financial Breakdown
        'items': [
          {
            'description': 'Servicii închiriere loc parcare',
            'quantity': 1,
            'unitPrice': double.parse(netAmount.toStringAsFixed(2)),
            'totalNet': double.parse(netAmount.toStringAsFixed(2)),
          }
        ],
        'totals': {
          'totalNet': double.parse(netAmount.toStringAsFixed(2)),
          'totalVat': double.parse(tvaAmount.toStringAsFixed(2)),
          'totalGross': totalAmount,
          'currency': 'RON',
          'serviceFeeIncluded': data['serviceFee'] ?? 0.0,
          'vatRate': '20%',
        },
        'paymentMethod': 'Virtual Wallet',
      });

      await _db
          .collection('reservations')
          .doc(reservationId)
          .update({'invoiceGenerated': true});
    } catch (e) {
      if (kDebugMode) print("Eroare generare factură: $e");
    }
  }

  // STORNO LOGIC (Canceling an invoice)
  Future<void> stornoInvoice(String invoiceId) async {
    await _db.collection('invoices').doc(invoiceId).update({
      'status': 'stornat',
      'stornatAt': FieldValue.serverTimestamp(),
    });
  }

  // DYNAMIC PRICING LOGIC
  PriceDetails getPriceDetails(
      ParkingSpace space, DateTime start, DateTime end) {
    final lang = LanguageService();
    final config = ConfigService();
    double basePrice = space.pricePerHour;
    int hours = end.difference(start).inHours;
    if (hours == 0) hours = 1;

    double baseTotal = basePrice * hours;
    double finalPriceTotal = 0;
    Set<String> appliedReasons = {};

    for (int i = 0; i < hours; i++) {
      DateTime currentHour = start.add(Duration(hours: i));
      List<double> activeMultipliers = [];
      List<String> currentHourReasons = [];

      // 1. Weekend Surge
      if (currentHour.weekday == DateTime.saturday ||
          currentHour.weekday == DateTime.sunday) {
        if (config.weekendMultiplier != 1.0) {
          activeMultipliers.add(config.weekendMultiplier);
          currentHourReasons.add(lang.translate('price_weekend'));
        }
      }

      // 2. Night Discount
      if (currentHour.hour >= 22 || currentHour.hour < 6) {
        if (config.nightMultiplier != 1.0) {
          activeMultipliers.add(config.nightMultiplier);
          currentHourReasons.add(lang.translate('price_night'));
        }
      }

      // 3. Peak Hour Surge
      if ((currentHour.hour >= 8 && currentHour.hour <= 10) ||
          (currentHour.hour >= 17 && currentHour.hour <= 19)) {
        if (config.peakMultiplier != 1.0) {
          activeMultipliers.add(config.peakMultiplier);
          currentHourReasons.add(lang.translate('price_peak'));
        }
      }

      double finalHourMultiplier = 1.0;
      if (activeMultipliers.isNotEmpty) {
        // Logica multiplicativă: 1.2 (Weekend) * 0.8 (Night) = 0.96 (4% reducere)
        for (var m in activeMultipliers) {
          finalHourMultiplier *= m;
        }

        final int percent = ((finalHourMultiplier - 1) * 100).abs().round();
        
        // Adăugăm motivul doar dacă există o schimbare reală de preț (!= 1.0)
        if (percent != 0) {
          final String sign = finalHourMultiplier > 1.0 ? "+" : "-";
          final String type = finalHourMultiplier > 1.0
              ? lang.translate('price_surge')
              : lang.translate('price_discount');
          
          final String combinedReason =
              "$type ${currentHourReasons.join(' + ')} ($sign$percent%)";
          appliedReasons.add(combinedReason);
        }
      }

      finalPriceTotal += basePrice * finalHourMultiplier;
    }

    // 4. Long Stay Discount (se aplică la final peste total)
    if (hours >= 5) {
      finalPriceTotal *= 0.9;
      appliedReasons.add(lang.translate('price_long_stay'));
    }

    double serviceFee = 2.0; // Taxă fixă platformă per rezervare
    double finalPriceWithFee = finalPriceTotal + serviceFee;
    
    double finalPrice = double.parse(finalPriceWithFee.toStringAsFixed(2));
    double effectiveMultiplier = finalPriceTotal / baseTotal;

    double ownerEarnings;
    double platformEarnings;

    if (effectiveMultiplier > 1.0) {
      // IF multiplier > 1.0 (Surge Pricing):
      // ownerEarnings = baseTotal * 0.8
      // platformEarnings = (baseTotal * 0.2) + (finalTotal - baseTotal) + serviceFee
      ownerEarnings = baseTotal * 0.8;
      platformEarnings = (baseTotal * 0.2) + (finalPriceTotal - baseTotal) + serviceFee;
    } else {
      // IF multiplier <= 1.0 (Discount or Normal Pricing):
      // ownerEarnings = finalTotal * 0.8
      // platformEarnings = finalTotal * 0.2 + serviceFee
      ownerEarnings = finalPriceTotal * 0.8;
      platformEarnings = (finalPriceTotal * 0.2) + serviceFee;
    }

    return PriceDetails(
      finalPrice: finalPrice,
      basePriceTotal: baseTotal,
      ownerEarnings: double.parse(ownerEarnings.toStringAsFixed(2)),
      platformEarnings: double.parse(platformEarnings.toStringAsFixed(2)),
      serviceFee: serviceFee,
      reasons: appliedReasons.toList(),
    );
  }

  double calculateDynamicPrice(
      ParkingSpace space, DateTime start, DateTime end) {
    return getPriceDetails(space, start, end).finalPrice;
  }

  Future<void> deleteReservation(String reservationId, String? spotId) async {
    if (spotId != null) {
      await _db
          .collection('parking_spaces')
          .doc(spotId)
          .update({'availableSpots': 1});
    }
    await _db.collection('reservations').doc(reservationId).delete();
  }

  Future<void> addCredits(String userId, double amount) async {
    await _db.collection('users').doc(userId).update({
      'walletBalance': FieldValue.increment(amount),
    });
  }

  // CANCELLATION & REFUND LOGIC
  Future<void> cancelReservation(String reservationId) async {
    final lang = LanguageService();
    final user = _auth.currentUser;
    if (user == null) throw Exception("Neautentificat");

    try {
      // 1. Găsim factura și datele rezervării
      final resSnap = await _db.collection('reservations').doc(reservationId).get();
      if (!resSnap.exists) throw Exception("Rezervarea nu există!");
      
      final data = resSnap.data() as Map<String, dynamic>;
      if (data['status'] != 'activ') {
        throw Exception("Doar rezervările active pot fi anulate!");
      }

      // Verificăm dacă suntem în fereastra de 10 minute pentru refund
      final Timestamp? createdAtTs = data['createdAt'] as Timestamp?;
      if (createdAtTs != null) {
        final DateTime createdAt = createdAtTs.toDate();
        final int diffMins = DateTime.now().difference(createdAt).inMinutes;
        if (diffMins > 10) {
          throw Exception(lang.currentLocale.languageCode == 'ro' 
            ? "Ne pare rău, rezervarea nu mai poate fi anulată după primele 10 minute."
            : "Sorry, the reservation can no longer be cancelled after the first 10 minutes.");
        }
      }

      final invoiceQuery = await _db.collection('invoices')
          .where('reservationId', isEqualTo: reservationId)
          .limit(1)
          .get();
      
      DocumentReference? invoiceRef;
      if (invoiceQuery.docs.isNotEmpty) {
        invoiceRef = invoiceQuery.docs.first.reference;
      }

      await _db.runTransaction((transaction) async {
        // Citim datele locului de parcare pentru a afla proprietarul
        final String spotId = data['spotId'];
        final spotSnap = await transaction.get(_db.collection('parking_spaces').doc(spotId));
        final spotData = spotSnap.exists ? (spotSnap.data() as Map<String, dynamic>) : {};
        final String parkingName = data['parkingName'] ?? 'Parcare';

        // 2. LOGICĂ REFUND (Știm deja că diffMins <= 10)
        final double totalPaid = (data['totalPrice'] ?? 0.0).toDouble();
        final double serviceFee = (data['serviceFee'] ?? 0.0).toDouble();
        
        // REȚINEM TAXA DE SERVICIU chiar și la refund (Profit Maximized Strategy)
        final double refundAmount = totalPaid - serviceFee;
        final double ownerDeduction = (data['ownerEarnings'] ?? 0.0).toDouble();

        // Returnăm banii UTILIZATORULUI (Suma totală minus taxa de sistem)
        DocumentReference userRef = _db.collection('users').doc(user.uid);
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(refundAmount),
        });

        // Log tranzacție refund pentru utilizator (Sub-colecție)
        final String refundTitle = '${lang.currentLocale.languageCode == 'ro' ? 'Anulare rezervare' : 'Reservation cancellation'}: $parkingName';
        final transRef = _db.collection('users').doc(user.uid).collection('transactions').doc();
        transaction.set(transRef, {
          'title': refundTitle,
          'amount': refundAmount,
          'type': 'refund',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Notificare utilizator - Refund
        DocumentReference userRefundNotifRef = _db.collection('notifications').doc();
        transaction.set(userRefundNotifRef, {
          'target': user.uid,
          'title': lang.currentLocale.languageCode == 'ro' ? '🔄 Refund Realizat' : '🔄 Refund Processed',
          'message': lang.currentLocale.languageCode == 'ro'
              ? 'Suma de $refundAmount RON a fost returnată. (Garanția de $serviceFee RON a fost reținută).'
              : 'The amount of $refundAmount RON has been returned. (Garanția of $serviceFee RON was retained).',
          'type': 'payment',
          'isRead': false,
          'showPopup': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // RETRAGEM BANII DE LA PROPRIETAR
        final String ownerId = spotData['ownerId'] ?? '';
        if (ownerId.isNotEmpty && ownerId != user.uid) {
          DocumentReference ownerRef = _db.collection('users').doc(ownerId);
          transaction.update(ownerRef, {
            'walletBalance': FieldValue.increment(-ownerDeduction),
          });

          // Log tranzacție (Scădere) pentru proprietar (Sub-colecție)
          final ownerTransRef = _db.collection('users').doc(ownerId).collection('transactions').doc();
          transaction.set(ownerTransRef, {
            'title': lang.currentLocale.languageCode == 'ro' 
                ? 'Rezervare anulată de client: $parkingName'
                : 'Reservation cancelled by client: $parkingName',
            'amount': -ownerDeduction,
            'type': 'refund_reversal',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // Marcam factura ca stornată (dacă există)
        if (invoiceRef != null) {
          transaction.update(invoiceRef, {
            'status': 'stornat',
            'stornatAt': FieldValue.serverTimestamp(),
          });
        }

        // 3. Notificare utilizator - Succes Anulare (ÎNTOTDEAUNA)
        DocumentReference userCancelNotifRef = _db.collection('notifications').doc();
        transaction.set(userCancelNotifRef, {
          'target': user.uid,
          'title': lang.currentLocale.languageCode == 'ro' ? '🚫 Rezervare Anulată' : '🚫 Reservation Cancelled',
          'message': lang.currentLocale.languageCode == 'ro'
              ? 'Rezervarea ta la $parkingName a fost anulată cu succes.'
              : 'Your reservation at $parkingName has been successfully cancelled.',
          'type': 'system',
          'isRead': false,
          'showPopup': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Update status rezervare
        transaction.update(resSnap.reference, {
          'status': 'anulat',
          'cancelledAt': FieldValue.serverTimestamp(),
          'endTime': FieldValue.serverTimestamp(),
        });

        // 5. Notificare proprietar (Dacă e cazul)
        if (ownerId.isNotEmpty && ownerId != user.uid) {
          DocumentReference ownerNotifRef = _db.collection('notifications').doc();
          transaction.set(ownerNotifRef, {
            'target': ownerId,
            'title': lang.currentLocale.languageCode == 'ro' ? '🚫 Rezervare Anulată' : '🚫 Reservation Cancelled',
            'message': lang.currentLocale.languageCode == 'ro'
                ? 'Clientul a anulat rezervarea la $parkingName. Suma a fost retrasă (refund 10 min).'
                : 'Client cancelled reservation at $parkingName. Amount was withdrawn (10 min refund).',
            'type': 'system',
            'isRead': false,
            'showPopup': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 6. Anulăm reminderele programate
      await _notifService.cancelExpiryReminders(reservationId);
    } catch (e) {
      debugPrint("Eroare anulare rezervare: $e");
      throw Exception(e.toString());
    }
  }

  // REPORTING LOGIC (Admin-Decision Based)
  Future<void> reportOccupied(String reservationId, String evidenceUrl) async {
    final lang = LanguageService();
    final user = _auth.currentUser;
    if (user == null) throw Exception("Neautentificat");

    try {
      final resSnap =
          await _db.collection('reservations').doc(reservationId).get();
      if (!resSnap.exists) throw Exception("Rezervarea nu există!");

      final data = resSnap.data() as Map<String, dynamic>;
      
      // BUG FIX: Verificăm dacă rezervarea a fost deja raportată sau soluționată
      final currentStatus = data['status'] ?? '';
      if (currentStatus == 'reported_occupied' || 
          currentStatus == 'reported_occupied_resolved' || 
          currentStatus == 'reported_occupied_rejected') {
        throw Exception(lang.currentLocale.languageCode == 'ro'
            ? "Această rezervare a fost deja raportată!"
            : "This reservation has already been reported!");
      }

      // 1. Verificăm timpul: Raportarea este permisă în primele 30 minute
      final Timestamp startTs = data['startTime'];
      final DateTime startTime = startTs.toDate();
      final diff = DateTime.now().difference(startTime).inMinutes;
      
      if (diff > 30) {
        throw Exception(lang.currentLocale.languageCode == 'ro' 
          ? "Raportarea se poate face doar în primele 30 de minute."
          : "Reporting is only allowed within the first 30 minutes.");
      }

      // 2. Doar schimbăm statusul și salvăm dovada. ADMINUL va decide refund-ul din dashboard.
      await _db.collection('reservations').doc(reservationId).update({
        'status': 'reported_occupied',
        'reportedAt': FieldValue.serverTimestamp(),
        'evidenceUrl': evidenceUrl,
        'refundStatus': 'pending', // Status nou pentru decizia adminului
      });

      // 3. Notificăm Adminul (creăm un tichet virtual)
      await _db.collection('notifications').add({
        'target': 'admin',
        'title': '🚨 Raportare Loc Ocupat',
        'message': 'Utilizatorul ${user.email} a raportat locul ${data['parkingName']} ca fiind ocupat abuziv.',
        'type': 'incident',
        'reservationId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'showPopup': true,
      });

      // 4. Notificăm Utilizatorul (Confirmare primire raport)
      await _db.collection('notifications').add({
        'target': user.uid,
        'title': lang.translate('notif_report_received_title'),
        'message': lang.translate('notif_report_received_msg'),
        'type': 'system',
        'reservationId': reservationId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'showPopup': true,
      });

    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Metodă pentru Admin (sau simulare) pentru a finaliza un raport
  Future<void> resolveReport(String reservationId, bool approve) async {
    final lang = LanguageService();
    try {
      // 1. Luăm datele rezervării (Refresh pt siguranță)
      final resSnap = await _db.collection('reservations').doc(reservationId).get();
      if (!resSnap.exists) return;
      
      final data = resSnap.data() as Map<String, dynamic>;
      final String userId = data['userId'] ?? '';
      final String spotId = data['spotId'] ?? '';
      final String parkingName = data['parkingName'] ?? 'Parcare';
      final double serviceFee = (data['serviceFee'] ?? 2.0).toDouble();

      if (userId.isEmpty) return;

      // 2. Găsim Proprietarul (Căutare forțată în colecția de parcări)
      String ownerId = '';
      final spotSnap = await _db.collection('parking_spaces').doc(spotId).get();
      if (spotSnap.exists) {
        ownerId = spotSnap.data()?['ownerId'] ?? '';
      }

      await _db.runTransaction((transaction) async {
        if (approve) {
          // --- CAZUL APROBAT (REFUND TAXĂ PROCESARE) ---

          // Returnăm DOAR taxa de procesare (cei 2 RON)
          transaction.update(_db.collection('users').doc(userId), {
            'walletBalance': FieldValue.increment(serviceFee),
          });

          // Log Tranzacție CHIRIAȘ
          final userTransRef = _db.collection('users').doc(userId).collection('transactions').doc();
          transaction.set(userTransRef, {
            'title': 'Refund Garanție Sistem: $parkingName',
            'amount': serviceFee,
            'type': 'refund',
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Notificare CHIRIAȘ
          transaction.set(_db.collection('notifications').doc(), {
            'target': userId,
            'title': '⚖️ Decizie Suport',
            'message': 'Raport aprobat! Garanția de sistem ($serviceFee RON) a fost returnată în portofel.',
            'type': 'payment',
            'reservationId': reservationId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'showPopup': true,
          });

          // Update Rezervare
          transaction.update(resSnap.reference, {
            'status': 'reported_occupied_resolved',
            'refundStatus': 'approved',
            'resolvedAt': FieldValue.serverTimestamp(),
          });

        } else {
          // --- CAZUL RESPINS ---
          
          // Notificare CHIRIAȘ
          transaction.set(_db.collection('notifications').doc(), {
            'target': userId,
            'title': '⚖️ Decizie Suport',
            'message': 'Raportul tău pentru $parkingName a fost respins. Garanția nu va fi returnată.',
            'type': 'system',
            'reservationId': reservationId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'showPopup': true,
          });

          // Update Rezervare
          transaction.update(resSnap.reference, {
            'status': 'reported_occupied_rejected',
            'refundStatus': 'rejected',
            'resolvedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      if (kDebugMode) print("CRITICAL TRANSACTION ERROR: $e");
      throw Exception("Eroare tranzacție support: $e");
    }
  }

  // EXTENSION LOGIC
  Future<void> extendReservation(String reservationId, int extraHours) async {
    final lang = LanguageService();
    final user = _auth.currentUser;
    if (user == null) throw Exception("Neautentificat");

    try {
      final resSnap = await _db.collection('reservations').doc(reservationId).get();
      if (!resSnap.exists) throw Exception("Rezervarea nu există!");

      final data = resSnap.data() as Map<String, dynamic>;
      final String spotId = data['spotId'];
      final DateTime currentEnd = (data['endTime'] as Timestamp).toDate();
      
      // 0. Verificăm dacă rezervarea nu a expirat deja
      if (currentEnd.isBefore(DateTime.now())) {
        throw Exception(lang.currentLocale.languageCode == 'ro'
            ? "Rezervarea a expirat și nu mai poate fi prelungită. Te rugăm să faci o rezervare nouă dacă dorești să mai rămâi."
            : "The reservation has expired and can no longer be extended. Please make a new reservation if you wish to stay longer.");
      }

      final DateTime newEnd = currentEnd.add(Duration(hours: extraHours));

      // 1. Verificăm dacă locul este disponibil pt noul interval
      bool overlap = await hasOverlap(spotId, currentEnd, newEnd);
      if (overlap) {
        throw Exception("Ne pare rău! Locul este deja rezervat de altcineva după timpul tău.");
      }

      // 2. Calculăm prețul suplimentar
      final spotSnap = await _db.collection('parking_spaces').doc(spotId).get();
      final space = ParkingSpace.fromFirestore(spotSnap);
      final priceDetails = getPriceDetails(space, currentEnd, newEnd);
      final double extraPrice = priceDetails.finalPrice;

      await _db.runTransaction((transaction) async {
        DocumentReference userRef = _db.collection('users').doc(user.uid);
        DocumentSnapshot userSnap = await transaction.get(userRef);
        double currentBalance = (userSnap.get('walletBalance') ?? 0).toDouble();

        if (currentBalance < extraPrice) {
          throw Exception("Fonduri insuficiente pt prelungire!");
        }

        // 3. Update Balanță & Tranzacție (Sub-colecție)
        transaction.update(userRef, {'walletBalance': currentBalance - extraPrice});
        
        final String transTitle = '${lang.translate('extend_reservation')}: ${data['parkingName']}';
        final transRef = _db.collection('users').doc(user.uid).collection('transactions').doc();
        transaction.set(transRef, {
          'title': transTitle,
          'amount': -extraPrice,
          'type': 'payment',
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // 4. Update Rezervare
        transaction.update(resSnap.reference, {
          'endTime': Timestamp.fromDate(newEnd),
          'totalPrice': (data['totalPrice'] ?? 0.0) + extraPrice,
          'platformEarnings': (data['platformEarnings'] ?? 0.0) + priceDetails.platformEarnings,
          'ownerEarnings': (data['ownerEarnings'] ?? 0.0) + priceDetails.ownerEarnings,
        });

        // 5. Plătim proprietarul pt extra
        final String ownerId = space.ownerId;
        if (ownerId.isNotEmpty && ownerId != user.uid) {
          DocumentReference ownerRef = _db.collection('users').doc(ownerId);
          transaction.update(ownerRef, {'walletBalance': FieldValue.increment(priceDetails.ownerEarnings)});
        }
      });
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // REVIEW SYSTEM
  Future<void> submitReview(
      String reservationId, double rating, String? comment) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final resSnap =
          await _db.collection('reservations').doc(reservationId).get();
      final resData = resSnap.data() as Map<String, dynamic>;
      final String spotId = resData['spotId'];

      // Document ID UNIC per utilizator și per loc de parcare (spotId_userId)
      final String reviewDocId = "${spotId}_${user.uid}";

      // Luăm datele utilizatorului pentru a le salva în review (denormalizare pt viteză)
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final String userName = userData['displayName'] ?? userData['name'] ?? "Utilizator";
      final String? userPhoto = userData['photoURL'];

      await _db.collection('reviews').doc(reviewDocId).set({
        'reservationId': reservationId,
        'userId': user.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'spotId': spotId,
        'rating': rating,
        'comment': comment ?? "",
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Marcăm rezervarea ca având review
      await _db.collection('reservations').doc(reservationId).update({
        'hasReview': true,
      });

      // Recalculăm rating-ul mediu al locației
      final allReviews = await _db
          .collection('reviews')
          .where('spotId', isEqualTo: spotId)
          .get();
      double totalRating = 0;
      for (var doc in allReviews.docs) {
        totalRating += (doc['rating'] as num).toDouble();
      }
      double avgRating = totalRating / allReviews.docs.length;

      // Dacă rating-ul scade sub 3, suspendăm locul
      Map<String, dynamic> updates = {
        'averageRating': avgRating,
        'reviewCount': allReviews.docs.length,
      };

      if (avgRating < 3.0 && allReviews.docs.length >= 3) {
        updates['isUnderMaintenance'] = true;
        updates['status'] = 'MAINTENANCE';
        updates['suspensionReason'] = 'Low rating (auto-suspended)';
      }

      await _db.collection('parking_spaces').doc(spotId).update(updates);

      // NOTIFICARE PENTRU PROPRIETAR
      final spotData = (await _db.collection('parking_spaces').doc(spotId).get()).data() ?? {};
      final String ownerId = spotData['ownerId'] ?? '';
      if (ownerId.isNotEmpty && ownerId != user.uid) {
        await _db.collection('notifications').add({
          'target': ownerId,
          'title': '⭐ Recenzie nouă primită',
          'message': 'Locul tău (${spotData['name']}) a primit $rating stele de la $userName.',
          'type': 'system',
          'isRead': false,
          'showPopup': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error submitting review: $e");
    }
  }

  // CONFLICT DETECTION LOGIC (Overlap check)
  Future<bool> hasOverlap(String spotId, DateTime start, DateTime end) async {
    final query = await _db
        .collection('reservations')
        .where('spotId', isEqualTo: spotId)
        .where('status', isEqualTo: 'activ')
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      final DateTime existingStart = (data['startTime'] as Timestamp).toDate();
      // Dacă endTime e null, considerăm că rezervarea e încă în desfășurare (infinită momentan)
      final DateTime existingEnd = data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 365));

      // Logica de overlap: (StartA < EndB) && (EndA > StartB)
      if (start.isBefore(existingEnd) && end.isAfter(existingStart)) {
        return true; // Există conflict
      }
    }
    return false;
  }

  bool _isWithinSchedule(ParkingSpace space, DateTime start, DateTime end) {
    try {
      if (space.weeklySchedule.isEmpty) return true;

      // 1. Verificare Mod Permanent (24/7)
      if (space.weeklySchedule['isAlwaysAvailable'] == true) return true;

      // 2. Verificare Mod Vacanță / Indisponibil
      if (space.weeklySchedule['isManuallyDisabled'] == true) return false;

      final dayName = _getDayName(start.weekday);
      final daySched = space.weeklySchedule[dayName];

      if (daySched == null || daySched['active'] == false) return false;

      final String startTimeStr = daySched['start'] ?? '00:00';
      final String endTimeStr = daySched['end'] ?? '23:59';

      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');

      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      final schedStart =
          DateTime(start.year, start.month, start.day, startHour, startMin);
      DateTime schedEnd =
          DateTime(start.year, start.month, start.day, endHour, endMin);

      if (schedEnd.isBefore(schedStart)) {
        schedEnd = schedEnd.add(const Duration(days: 1));
      }

      return (start.isAtSameMomentAs(schedStart) ||
              start.isAfter(schedStart)) &&
          (end.isAtSameMomentAs(schedEnd) || end.isBefore(schedEnd));
    } catch (e) {
      return true;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }
}
