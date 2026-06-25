import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double weekendMultiplier = 1.1;
  double nightMultiplier = 0.9;
  double peakMultiplier = 1.7;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    try {
      // Ascultăm în timp real modificările din Admin
      _db.collection('settings').doc('pricing').snapshots().listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          weekendMultiplier = (data['weekendSurge'] ?? 1.1).toDouble();
          nightMultiplier = (data['nightDiscount'] ?? 0.9).toDouble();
          peakMultiplier = (data['peakHourSurge'] ?? 1.7).toDouble();
          _isLoaded = true;
          notifyListeners();
          if (kDebugMode) print("Configurație prețuri actualizată din Admin");
        }
      });
    } catch (e) {
      if (kDebugMode) print("Eroare la încărcarea configurației: $e");
    }
  }
}
