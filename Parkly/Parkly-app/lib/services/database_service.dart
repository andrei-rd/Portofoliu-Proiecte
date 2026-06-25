import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/firebase_error_handler.dart';

class DatabaseService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DatabaseService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // USERS

  Future<void> saveUserData({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
    String role = 'user',
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'role': role,
        'walletBalance': 50.0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log creditul inițial în tranzacții dacă e utilizator nou
      final transQuery = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('type', isEqualTo: 'initial_credit')
          .limit(1)
          .get();

      if (transQuery.docs.isEmpty) {
        await _db.collection('users').doc(uid).collection('transactions').add({
          'title': 'Bonus de bun venit',
          'amount': 50.0,
          'type': 'initial_credit',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Database Error (saveUserData): ${appException.code}");
      }
      throw appException;
    }
  }

  Stream<DocumentSnapshot> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    try {
      await _db.collection('users').doc(uid).update({'displayName': newName});
      // Also update the local Firebase Auth user profile if available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.updateDisplayName(newName);
        await currentUser.reload();
      }
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        if (data.containsKey('displayName')) {
          await currentUser.updateDisplayName(data['displayName']);
        }
        if (data.containsKey('photoURL')) {
          await currentUser.updatePhotoURL(data['photoURL']);
        }
        await currentUser.reload();
      }
    } catch (e) {
      if (kDebugMode) print("Database Error (updateUserProfile): $e");
      throw FirebaseErrorHandler.handle(e);
    }
  }

  Future<void> updatePresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      } catch (e) {
        if (kDebugMode) print("Presence Update Error: $e");
      }
    }
  }

  Future<void> setOffline() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': false,
        });
      } catch (e) {
        if (kDebugMode) print("Set Offline Error: $e");
      }
    }
  }

  Future<void> deactivateAccount(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("Database Error (deactivateAccount): $e");
      throw FirebaseErrorHandler.handle(e);
    }
  }

  Future<void> deleteUserData(String uid) async {
    try {
      // In a real app, you might want to delete cars and reservations too
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      if (kDebugMode) print("Database Error (deleteUserData): $e");
      throw FirebaseErrorHandler.handle(e);
    }
  }

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('user_avatars').child('$uid.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      await updateUserProfile(uid, {'photoURL': url});
      return url;
    } catch (e) {
      if (kDebugMode) print("Storage Error (uploadProfileImage): $e");
      throw FirebaseErrorHandler.handle(e);
    }
  }

  // CARS

  Future<void> addUserCar(String uid, String model, String plate, String vin,
      String emission) async {
    try {
      await _db.collection('users').doc(uid).collection('cars').add({
        'model': model,
        'plate': plate,
        'vin': vin,
        'emission': emission,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  Stream<QuerySnapshot> getUserCars(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('cars')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateUserCar(String uid, String carId, String model,
      String plate, String vin, String emission) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('cars')
          .doc(carId)
          .update({
        'model': model,
        'plate': plate,
        'vin': vin,
        'emission': emission,
      });
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  Future<void> updateFCMToken(String uid, String? token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      if (kDebugMode) print("FCM Token Error: $e");
    }
  }

  Future<void> deleteUserCar(String uid, String carId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('cars')
          .doc(carId)
          .delete();
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  //PARKING SPOTS

  Future<void> addParkingSpot({
    required String ownerId,
    required String title,
    required String description,
    required String address,
    required double pricePerHour,
    required GeoPoint location,
    List<String> images = const [],
  }) async {
    try {
      await _db.collection('parking_spots').add({
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'address': address,
        'location': location,
        'pricePerHour': pricePerHour,
        'isAvailable': true,
        'images': images,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Database Error (addParkingSpot): ${appException.code}");
      }
      throw appException;
    }
  }

  Stream<QuerySnapshot> getAvailableSpots() {
    return _db
        .collection('parking_spots')
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  //RESERVATIONS

  Future<void> createReservation({
    required String userId,
    required String spotId,
    required String parkingName,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
  }) async {
    try {
      final userRef = _db.collection('users').doc(userId);

      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final double balance =
            (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();

        if (balance < totalPrice) {
          throw 'Insufficient funds';
        }

        // 1. Creare rezervare
        final resRef = _db.collection('reservations').doc();
        transaction.set(resRef, {
          'userId': userId,
          'spotId': spotId,
          'parkingName': parkingName,
          'startTime': startTime,
          'endTime': endTime,
          'totalPrice': totalPrice,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Scădere bani din portofel
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(-totalPrice),
        });

        // 3. Adăugare în istoricul de tranzacții (sub-colecție utilizator)
        final transRef = _db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(transRef, {
          'title': 'Plată parcare: $parkingName',
          'amount': -totalPrice,
          'type': 'payment',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Database Error (createReservation): ${appException.code}");
      }
      throw appException;
    }
  }

  Stream<QuerySnapshot> getUserReservations(String userId) {
    return _db
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateReservationStatus(String resId, String status) async {
    try {
      await _db.collection('reservations').doc(resId).update({
        'status': status,
        if (status == 'completat') 'endTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  Future<void> addWalletCredits(String uid, double amount) async {
    try {
      await _db.collection('users').doc(uid).update({
        'walletBalance': FieldValue.increment(amount),
      });

      // Log tranzacție
      await _db.collection('users').doc(uid).collection('transactions').add({
        'title': 'Alimentare portofel (Bonus Admin)',
        'amount': amount,
        'type': 'top_up',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print("Database Error: $e");
    }
  }

  Future<void> transferMoneyByEmail({
    required String senderUid,
    required String recipientEmail,
    required double amount,
    required String details,
  }) async {
    try {
      final recipientQuery = await _db
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .limit(1)
          .get();

      if (recipientQuery.docs.isEmpty) {
        throw 'User not found';
      }

      final recipientId = recipientQuery.docs.first.id;
      final senderRef = _db.collection('users').doc(senderUid);
      final recipientRef = _db.collection('users').doc(recipientId);

      if (senderUid == recipientId) {
        throw 'Cannot transfer to yourself';
      }

      await _db.runTransaction((transaction) async {
        final senderDoc = await transaction.get(senderRef);
        if (!senderDoc.exists) throw 'Sender not found';

        final double currentBalance =
            (senderDoc.data()?['walletBalance'] ?? 0.0).toDouble();

        if (currentBalance < amount) {
          throw 'Insufficient funds';
        }

        transaction.update(senderRef, {
          'walletBalance': FieldValue.increment(-amount),
        });

        transaction.update(recipientRef, {
          'walletBalance': FieldValue.increment(amount),
        });

        // Înregistrare pentru expeditor (sub-colecție)
        final senderTransRef = _db.collection('users').doc(senderUid).collection('transactions').doc();
        transaction.set(senderTransRef, {
          'title': 'Transfer trimis către $recipientEmail',
          'recipientEmail': recipientEmail,
          'amount': -amount,
          'type': 'transfer_out',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Înregistrare pentru destinatar (sub-colecție)
        final recipientTransRef = _db.collection('users').doc(recipientId).collection('transactions').doc();
        transaction.set(recipientTransRef, {
          'title': 'Transfer primit de la ${senderDoc.data()?['email']}',
          'senderEmail': senderDoc.data()?['email'],
          'amount': amount,
          'type': 'transfer_in',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Notificare pentru destinatar
        final notifRef = _db.collection('notifications').doc();
        transaction.set(notifRef, {
          'target': recipientId,
          'title': '💸 Ai primit bani!',
          'message': 'Utilizatorul ${senderDoc.data()?['email']} ți-a trimis $amount RON.',
          'type': 'payment',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (kDebugMode) print("Transfer Error: $e");
      rethrow;
    }
  }

  // FAVORITES

  Future<void> toggleFavorite(
      String uid, String parkingId, bool isFavorite) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      if (isFavorite) {
        await docRef.update({
          'favorites': FieldValue.arrayUnion([parkingId])
        });
      } else {
        await docRef.update({
          'favorites': FieldValue.arrayRemove([parkingId])
        });
      }
    } catch (e) {
      if (kDebugMode) print("Favorite Error: $e");
    }
  }

  Stream<List<String>> getUserFavorites(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        return List<String>.from(data['favorites'] ?? []);
      }
      return [];
    });
  }
}
