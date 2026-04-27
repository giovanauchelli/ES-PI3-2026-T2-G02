import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<UserCredential> login({
    required String email,
    required String senha,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String senha,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
