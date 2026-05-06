import 'package:firebase_auth/firebase_auth.dart';

class PasswordRecoveryService {
  PasswordRecoveryService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}