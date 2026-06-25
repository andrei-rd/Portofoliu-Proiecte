import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkly/services/parking_service.dart';
import 'package:parkly/models/parking_space.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late ParkingService parkingService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(signedIn: true);
    parkingService = ParkingService(db: fakeFirestore, auth: mockAuth);
  });

  group('ParkingService Unit Tests', () {
    test('addSingleSpot adds a spot to Firestore', () async {
      final spotData = {
        'name': 'Test Spot',
        'address': 'Test Address',
        'latitude': 45.6427,
        'longitude': 25.5887,
        'pricePerHour': 5.0,
      };

      await parkingService.addSingleSpot(spotData);

      final snapshot = await fakeFirestore.collection('parking_spaces').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['name'], 'Test Spot');
      expect(snapshot.docs.first.data()['totalSpots'], 1);
    });

    test('deleteSpot removes a spot from Firestore', () async {
      final docRef = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Spot to Delete',
      });
      final docId = docRef.id;

      await parkingService.deleteSpot(docId);

      final snapshot =
          await fakeFirestore.collection('parking_spaces').doc(docId).get();
      expect(snapshot.exists, false);
    });

    test('getParkingSpaces returns a stream of grouped parking spaces',
        () async {
      // Add two spots with the same name and address (should be grouped)
      await fakeFirestore.collection('parking_spaces').add({
        'name': 'Central Park',
        'address': 'Downtown 1',
        'latitude': 45.0,
        'longitude': 25.0,
        'pricePerHour': 10.0,
        'availableSpots': 1,
      });
      await fakeFirestore.collection('parking_spaces').add({
        'name': 'Central Park',
        'address': 'Downtown 1',
        'latitude': 45.0,
        'longitude': 25.0,
        'pricePerHour': 10.0,
        'availableSpots': 0,
      });

      final stream = parkingService.getParkingSpaces();
      final spaces = await stream.first;

      expect(spaces.length, 1);
      expect(spaces.first.name, 'Central Park');
      expect(spaces.first.totalSpots, 2);
      expect(spaces.first.availableSpots, 1);
    });

    test('reserveSpot creates a reservation and updates spot availability',
        () async {
      // Add a user with balance
      final user = mockAuth.currentUser!;
      await fakeFirestore.collection('users').doc(user.uid).set({
        'walletBalance': 100.0,
      });

      final spotDoc = await fakeFirestore.collection('parking_spaces').add({
        'name': 'Reserve Me',
        'address': 'Address 1',
        'latitude': 45.0,
        'longitude': 25.0,
        'pricePerHour': 5.0,
        'availableSpots': 1,
      });

      final space = ParkingSpace(
        id: spotDoc.id,
        docIds: [spotDoc.id],
        ownerId: 'test-uid',
        ownerName: 'Test User',
        name: 'Reserve Me',
        address: 'Address 1',
        latitude: 45.0,
        longitude: 25.0,
        pricePerHour: 5.0,
        totalSpots: 1,
        availableSpots: 1,
        imageUrl: '',
      );

      await parkingService.reserveSpot(space, space.pricePerHour);

      // Check if spot is now unavailable
      final updatedSpot = await fakeFirestore
          .collection('parking_spaces')
          .doc(spotDoc.id)
          .get();
      expect(updatedSpot.data()?['availableSpots'], 0);

      // Check if reservation was created
      final reservations = await fakeFirestore.collection('reservations').get();
      expect(reservations.docs.length, 1);
      expect(reservations.docs.first.data()['parkingName'], 'Reserve Me');
      expect(
          reservations.docs.first.data()['userId'], mockAuth.currentUser?.uid);
    });
  });
}
