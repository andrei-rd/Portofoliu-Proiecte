import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/services/parking_service.dart';
import 'package:parkly/utils/app_exception.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late ParkingService parkingService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(signedIn: true);
    parkingService = ParkingService(db: fakeFirestore, auth: mockAuth);
  });

  group('Repost Functionality Tests', () {
    test('getParkingSpaces populates docIds and owner info', () async {
      await fakeFirestore.collection('parking_spaces').add({
        'name': 'Group A',
        'address': 'Address A',
        'latitude': 44.0,
        'longitude': 26.0,
        'pricePerHour': 10.0,
        'availableSpots': 1,
        'ownerId': 'owner123',
        'ownerName': 'Test Owner',
      });
      await fakeFirestore.collection('parking_spaces').add({
        'name': 'Group A',
        'address': 'Address A',
        'latitude': 44.0,
        'longitude': 26.0,
        'pricePerHour': 10.0,
        'availableSpots': 1,
        'ownerId': 'owner123',
        'ownerName': 'Test Owner',
      });

      final stream = parkingService.getParkingSpaces();
      final spaces = await stream.first;

      expect(spaces.length, 1);
      expect(spaces.first.docIds.length, 2);
      expect(spaces.first.ownerName, 'Test Owner');
    });

    test('repostAllInGroup fails if there is an active reservation', () async {
      final doc1 = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Spot 1',
        'availableSpots': 0,
      });

      // Add active reservation
      await fakeFirestore.collection('reservations').add({
        'spotId': doc1.id,
        'status': 'activ',
        'endTime':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
      });

      expect(
        () => parkingService.repostAllInGroup([doc1.id]),
        throwsA(isA<AppException>()),
      );
    });

    test('repostAllInGroup succeeds if reservation is expired', () async {
      final doc1 = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Spot 1',
        'availableSpots': 0,
      });

      // Add expired reservation
      await fakeFirestore.collection('reservations').add({
        'spotId': doc1.id,
        'status': 'activ',
        'endTime': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1))),
      });

      await parkingService.repostAllInGroup([doc1.id]);

      final updatedDoc1 =
          await fakeFirestore.collection('parking_spaces').doc(doc1.id).get();
      expect(updatedDoc1.data()?['availableSpots'], 1);
    });

    test('unpostAllInGroup marks all spots as unavailable', () async {
      final doc1 = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Spot 1',
        'availableSpots': 1,
      });
      final doc2 = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Spot 2',
        'availableSpots': 1,
      });

      await parkingService.unpostAllInGroup([doc1.id, doc2.id]);

      final updatedDoc1 =
          await fakeFirestore.collection('parking_spaces').doc(doc1.id).get();
      final updatedDoc2 =
          await fakeFirestore.collection('parking_spaces').doc(doc2.id).get();

      expect(updatedDoc1.data()?['availableSpots'], 0);
      expect(updatedDoc2.data()?['availableSpots'], 0);
    });
  });
}
