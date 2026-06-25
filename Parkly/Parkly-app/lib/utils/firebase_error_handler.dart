import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'app_exception.dart';

class FirebaseErrorHandler {
  static AppException handle(dynamic error) {
    String message =
        'A aparut o eroare neasteptata. Te rugam să încerci din nou.';
    String? code;

    if (error is FirebaseAuthException) {
      code = error.code;
      switch (error.code) {
        case 'user-not-found':
          message = 'Nu a fost găsit niciun cont cu această adresă de email.';
          break;
        case 'wrong-password':
          message = 'Parola introdusă este incorectă. Încearcă din nou.';
          break;
        case 'email-already-in-use':
          message = 'Această adresă de email este deja utilizată de alt cont.';
          break;
        case 'invalid-email':
          message = 'Adresa de email nu are un format valid.';
          break;
        case 'weak-password':
          message = 'Parola este prea slabă. Folosește cel puțin 6 caractere.';
          break;
        case 'network-request-failed':
          message = 'Eroare de rețea. Verifică conexiunea la internet.';
          break;
        case 'too-many-requests':
          message = 'Prea multe încercări. Încearcă din nou mai târziu.';
          break;
        case 'operation-not-allowed':
          message = 'Această metodă de autentificare nu este activată.';
          break;
        case 'user-disabled':
          message = 'Acest cont a fost dezactivat de un administrator.';
          break;
        case 'requires-recent-login':
          message = 'Această acțiune necesită o re-autentificare recentă.';
          break;
        case 'invalid-credential':
          message = 'Credentialele furnizate sunt invalide sau expirate.';
          break;
        case 'account-exists-with-different-credential':
          message = 'Există deja un cont cu acest email dar cu altă metodă de login.';
          break;
        default:
          message = error.message ?? message;
      }
    } else if (error is FirebaseException) {
      code = error.code;
      switch (error.code) {
        case 'permission-denied':
          message =
              'Nu ai permisiunea necesară pentru a efectua această acțiune.';
          break;
        case 'unavailable':
          message =
              'Serviciul este temporar indisponibil. Încearcă mai târziu.';
          break;
        case 'not-found':
          message = 'Documentul solicitat nu a fost găsit.';
          break;
        case 'deadline-exceeded':
          message = 'Operațiunea a durat prea mult. Verifică internetul.';
          break;
        case 'already-exists':
          message = 'Acest document există deja în baza de date.';
          break;
        case 'resource-exhausted':
          message =
              'Limita de resurse a fost atinsă (Quotas). Contactează suportul.';
          break;
        default:
          message = error.message ?? message;
      }
    } else if (error is PlatformException) {
      code = error.code;
      message = error.message ?? 'Eroare de sistem: ${error.code}';
      if (error.code == '10' || error.code == 'DEVELOPER_ERROR') {
        message = 'Eroare 10: Semnătura SHA-1 a laptopului nu este în Firebase Console.';
      }
    }

    return AppException(message, code: code);
  }
}
