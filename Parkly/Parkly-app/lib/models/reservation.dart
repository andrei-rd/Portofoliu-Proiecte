import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String? id;
  final String userId;
  final String parkingId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final String status;

  Reservation({
    this.id,
    required this.userId,
    required this.parkingId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'parkingId': parkingId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalPrice': totalPrice,
      'status': status,
    };
  }

  factory Reservation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Reservation(
      id: doc.id,
      userId: data['userId'] ?? '',
      parkingId: data['parkingId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      status: data['status'] ?? 'activ',
    );
  }
}
