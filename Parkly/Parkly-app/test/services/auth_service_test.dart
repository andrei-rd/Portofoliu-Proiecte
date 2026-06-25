import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parkly/services/auth_service.dart';
import 'package:parkly/services/database_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  DatabaseService
])
void main() {
  late MockFirebaseAuth fakeAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockDatabaseService mockDatabaseService;
  late AuthService authService;

  setUp(() {
    fakeAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockDatabaseService = MockDatabaseService();
    authService = AuthService(
      auth: fakeAuth,
      googleSignIn: mockGoogleSignIn,
      db: mockDatabaseService,
    );
  });

  group('AuthService Tests', () {
    test('registerWithEmailPassword creates a user and saves to database',
        () async {
      const email = 'test@example.com';
      const password = 'password123';
      const name = 'Test User';

      final user =
          await authService.registerWithEmailPassword(email, password, name);

      expect(user, isNotNull);
      expect(user!.email, email);

      // Verify database save was called
      verify(mockDatabaseService.saveUserData(
        uid: anyNamed('uid'),
        email: email,
        displayName: name,
      )).called(1);
    });

    test('signInWithEmailPassword signs in successfully', () async {
      const email = 'test@example.com';
      const password = 'password123';

      // Create user first
      await fakeAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      final user = await authService.signInWithEmailPassword(email, password);

      expect(user, isNotNull);
      expect(user!.email, email);
    });

    test('signOut signs out correctly', () async {
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      await authService.signOut();

      expect(fakeAuth.currentUser, isNull);
      verify(mockGoogleSignIn.signOut()).called(1);
    });
  });
}
