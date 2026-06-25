import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DatabaseService databaseService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    databaseService = DatabaseService(firestore: fakeFirestore);
  });

  group('DatabaseService Tests', () {
    test('saveUserData saves user data correctly', () async {
      const uid = 'test_uid';
      const email = 'test@example.com';
      const name = 'Test User';

      await databaseService.saveUserData(
        uid: uid,
        email: email,
        displayName: name,
      );

      final userDoc = await fakeFirestore.collection('users').doc(uid).get();

      expect(userDoc.exists, true);
      expect(userDoc.data()?['email'], email);
      expect(userDoc.data()?['displayName'], name);
      expect(userDoc.data()?['role'], 'user');
    });

    test('addParkingSpot adds a spot correctly', () async {
      const ownerId = 'owner_uid';
      const title = 'Test Parking';
      const address = '123 Street';
      const price = 5.0;
      const location = GeoPoint(45.0, 25.0);

      await databaseService.addParkingSpot(
        ownerId: ownerId,
        title: title,
        description: 'A test parking spot',
        address: address,
        pricePerHour: price,
        location: location,
      );

      final spots = await fakeFirestore.collection('parking_spots').get();

      expect(spots.docs.length, 1);
      expect(spots.docs.first.data()['title'], title);
      expect(spots.docs.first.data()['ownerId'], ownerId);
      expect(spots.docs.first.data()['pricePerHour'], price);
    });

    test('createReservation adds a reservation correctly', () async {
      const userId = 'user_uid';
      const spotId = 'spot_uid';
      final startTime = DateTime.now();
      final endTime = startTime.add(const Duration(hours: 2));
      const price = 10.0;

      await databaseService.createReservation(
        userId: userId,
        spotId: spotId,
        parkingName: 'Test Parking',
        startTime: startTime,
        endTime: endTime,
        totalPrice: price,
      );

      final reservations = await fakeFirestore.collection('reservations').get();

      expect(reservations.docs.length, 1);
      expect(reservations.docs.first.data()['userId'], userId);
      expect(reservations.docs.first.data()['spotId'], spotId);
      expect(reservations.docs.first.data()['totalPrice'], price);
    });
  });
}
