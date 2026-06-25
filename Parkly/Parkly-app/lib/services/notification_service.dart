import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'language_service.dart';
import 'dart:async';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  StreamSubscription? _reportListener;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Initialize Timezone
    tz.initializeTimeZones();

    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    if (!kIsWeb) {
      // 1. Define high importance channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // 2. Create the channel on the device
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 3. Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(initializationSettings);
    }

    // Get FCM Token
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        saveTokenToFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) print("Error getting FCM token: $e");
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      saveTokenToFirestore(newToken);
    });

    // Handle Foreground Messages (FCM)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notifications',
              importance: Importance.max,
              priority: Priority.max,
              icon: '@mipmap/launcher_icon',
              fullScreenIntent: true,
            ),
          ),
        );
      }
    });
  }

  StreamSubscription? _globalListener;

  /// Pornește ascultarea notificărilor din Firestore (Pop-up-uri interne)
  void startFirestoreNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    _globalListener?.cancel();

    // Ascultăm tot ce este vizat către user sau global
    _globalListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('target', whereIn: [user?.uid, 'all'])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // Ne interesează doar documentele nou adăugate în stream
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // Verificăm dacă notificarea e recentă (ultima 2 minute) 
          final Timestamp? createdAt = data['createdAt'] as Timestamp?;
          bool isRecent = true;
          if (createdAt != null) {
            final diff = DateTime.now().difference(createdAt.toDate()).inSeconds;
            if (diff.abs() > 120) isRecent = false; 
          }

          // AFISĂM POP-UP DACĂ:
          // 1. Este recentă
          // 2. Este marcată explicit cu showPopup: true SAU este un anunț global (target: all)
          bool forcePopup = (data['showPopup'] == true) || (data['target'] == 'all');
          
          if (isRecent && forcePopup) {
            _localNotifications.show(
              change.doc.id.hashCode,
              data['title'] ?? 'Parkly',
              data['message'] ?? '',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'high_importance_channel',
                  'Notifications',
                  importance: Importance.max,
                  priority: Priority.max,
                  icon: '@mipmap/launcher_icon',
                  playSound: true,
                  enableVibration: true,
                  fullScreenIntent: true,
                ),
              ),
            );
            
            // Dezactivăm showPopup pentru a nu se repeta (doar pt notificări personale)
            if (data['target'] != 'all' && data['showPopup'] == true) {
              change.doc.reference.update({'showPopup': false});
            }
          }
        }
      }
    });
  }

  Future<void> scheduleExpiryReminders(
      String reservationId, String parkingName, DateTime endTime) async {
    if (kIsWeb) return;

    final now = DateTime.now();
    // Folosim un ID determinist bazat pe reservationId, dar limitat la 31 biți pentru Android
    final int baseId = reservationId.hashCode & 0x7FFFFFFF;

    // Reminder 5 minute înainte
    final fiveMinBefore = endTime.subtract(const Duration(minutes: 5));
    if (fiveMinBefore.isAfter(now)) {
      // 1. Programăm notificarea locală
      await _localNotifications.zonedSchedule(
        baseId + 5,
        '⏳ Atenție: Expiră parcarea!',
        'Rezervarea ta la $parkingName se termină în 5 minute.',
        tz.TZDateTime.from(fiveMinBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Remindere Parcare',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // 2. Salvăm și în Firestore pentru a apărea în tab-ul de mesaje
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Notă: Salvăm cu reservationId pentru a putea anula dacă e cazul
        await FirebaseFirestore.instance.collection('notifications').add({
          'target': user.uid,
          'reservationId': reservationId,
          'title': '⏳ Atenție: Expiră parcarea!',
          'message': 'Rezervarea ta la $parkingName se termină în 5 minute.',
          'type': 'system',
          'isRead': false,
          'createdAt': Timestamp.fromDate(fiveMinBefore),
        });
      }
    }

    // Reminder 1 minut înainte
    final oneMinBefore = endTime.subtract(const Duration(minutes: 1));
    if (oneMinBefore.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        baseId + 1,
        '🚨 Urgent: Parcare aproape de final!',
        'Mai ai doar 1 minut la $parkingName. Eliberează locul sau prelungește!',
        tz.TZDateTime.from(oneMinBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Remindere Parcare',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Reminder EXACT la final (Solicitare Review)
    if (endTime.isAfter(now)) {
      await _localNotifications.zonedSchedule(
        baseId + 10,
        '⭐ Cum a fost parcare la $parkingName?',
        'Timpul tău a expirat. Te rugăm să lași o recenzie despre acest loc!',
        tz.TZDateTime.from(endTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Solicitare Feedback',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Salvăm și în Firestore pentru tab-ul de mesaje la final
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'target': user.uid,
          'reservationId': reservationId,
          'title': '⭐ Lasă o recenzie',
          'message': 'Te rugăm să ne spui cum a fost experiența ta la $parkingName.',
          'type': 'system',
          'isRead': false,
          'createdAt': Timestamp.fromDate(endTime),
        });
      }
    }
  }

  Future<void> cancelExpiryReminders(String reservationId) async {
    if (kIsWeb) return;
    
    final int baseId = reservationId.hashCode & 0x7FFFFFFF;

    // 1. Anulăm notificările locale
    await _localNotifications.cancel(baseId + 5);
    await _localNotifications.cancel(baseId + 1);

    // 2. Ștergem notificările programate din Firestore care nu au fost încă "afișate"
    try {
      final pendingNotifs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('reservationId', isEqualTo: reservationId)
          .get();
      
      for (var doc in pendingNotifs.docs) {
        // Ștergem doar dacă e în viitor sau dacă e de tip 'system' (remindere)
        // pentru a nu șterge istoricul de chat sau alte notificări importante.
        final data = doc.data();
        if (data['type'] == 'system') {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) print("Eroare la ștergerea notificărilor Firestore: $e");
    }
  }

  Future<void> saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print("FCM Token saved to Firestore for user: ${user.uid}");
        }
      } catch (e) {
        if (kDebugMode) print("Error saving FCM token: $e");
      }
    }
  }

  /// Watcher care ascultă schimbările de status pe rezervările raportate
  /// și creează automat documente de notificare dacă adminul a uitat să le creeze.
  void startReportDecisionWatcher() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _reportListener?.cancel();
      return;
    }

    _reportListener?.cancel();
    _reportListener = FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'reported_occupied')
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        // Verificăm atât modificările cât și documentele care sunt deja în statusul final la pornirea stream-ului
        final data = change.doc.data() as Map<String, dynamic>;
        final String refundStatus = data['refundStatus'] ?? 'pending';
        final bool alreadyNotified = data['decisionNotified'] ?? false;

        if (refundStatus != 'pending' && !alreadyNotified) {
          final lang = LanguageService();
          final String resId = change.doc.id;
          
          if (kDebugMode) print("WATCHER: Detectată decizie refund pentru $resId: $refundStatus");

          // 1. Marcăm imediat rezervarea ca notificată pentru a preveni buclele
          await change.doc.reference.update({'decisionNotified': true});

          // 2. Creăm notificarea în colecția globală pentru a apărea în Mesaje
          await FirebaseFirestore.instance.collection('notifications').add({
            'target': user.uid,
            'title': lang.translate('notif_report_decision_title'),
            'message': refundStatus == 'approved' 
                ? lang.translate('notif_report_decision_refund')
                : lang.translate('notif_report_decision_rejected'),
            'type': refundStatus == 'approved' ? 'payment' : 'system',
            'reservationId': resId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });

          // 3. Notificare Locală (Push instant)
          _localNotifications.show(
            resId.hashCode,
            lang.translate('notif_report_decision_title'),
            refundStatus == 'approved' 
                ? lang.translate('notif_report_decision_refund')
                : lang.translate('notif_report_decision_rejected'),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'Decizii Suport',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> refreshInstanceToken() async {
    try {
      String? token;
      if (kIsWeb) {
        // Pe Web, getToken are nevoie de vapidKey.
        // token = await _fcm.getToken(vapidKey: "CHEIA_TA_VAPID_AICI");
        return; // Sărim peste pe web dacă nu avem vapidKey configurat corect
      } else {
        token = await _fcm.getToken();
      }
      
      if (token != null) {
        await saveTokenToFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) print("Error refreshing FCM token: $e");
    }
  }
}
