import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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

  Future<String?> getUserFullName(String uid) async {
    final snapshot = await _firestore.collection('usuarios').doc(uid).get();
    final data = snapshot.data();
    final value = data?['fullName'] as String?;

    if (value == null) return null;

    final fullName = value.trim();
    return fullName.isEmpty ? null : fullName;
  }

  String? formatDisplayName(String? fullName) {
    if (fullName == null) return null;

    final partes = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) return null;
    if (partes.length == 1) return partes.first;
    if (partes.length == 2) return '${partes[0]} ${partes[1]}';

    final primeiroNome = partes.first;
    final segundoNome = partes[1];
    final ultimoNome = partes.last;

    if (segundoNome.length > 2) {
      return '$primeiroNome $segundoNome';
    }

    if (ultimoNome.length > 2) {
      return '$primeiroNome $ultimoNome';
    }

    final restantesAbreviados = partes
        .skip(1)
        .map((parte) => '${parte[0].toUpperCase()}.')
        .join(' ');

    return '$primeiroNome $restantesAbreviados';
  }

  Future<String?> getUserDisplayName(String uid) async {
    final fullName = await getUserFullName(uid);
    return formatDisplayName(fullName);
  }

  User? get currentUser => _auth.currentUser;
}
