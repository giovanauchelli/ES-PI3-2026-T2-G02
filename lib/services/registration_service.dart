import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario.dart';

class RegistrationService {
  // RegistrationService({AuthService? authService, FirebaseFirestore? firestore})
  //   : _authService = authService ?? AuthService(),
  //     _firestore = firestore ?? FirebaseFirestore.instance;


  final FirebaseAuth _authService = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser(Usuario usuario) async {
    final email = usuario.email?.trim().toLowerCase();
    final senha = usuario.senha;
    final cpf = usuario.cpf?.replaceAll(RegExp(r'[^0-9]'), '');
    final nome = usuario.fullName?.trim();
    final telefone = usuario.telefone?.replaceAll(RegExp(r'[^0-9]'), '');

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'E-mail invalido.',
      );
    }

    if (senha == null || senha.isEmpty) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Senha obrigatoria.',
      );
    }

    if (cpf == null || cpf.length != 11) {
      throw FirebaseAuthException(
        code: 'invalid-cpf',
        message: 'CPF invalido.',
      );
    }

    // UserCredential? credential;

    try {
      final credential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      
      final currentUser = credential.user;

      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Nao foi possivel identificar o usuario criado.',
        );
      }

      if (nome != null && nome.isNotEmpty) {
        await currentUser.updateDisplayName(nome);
      }

      final payload = usuario.toMap(includeSenha: false)
        ..['uid'] = currentUser.uid
        ..['cpf'] = cpf
        ..['email'] = email
        ..['telefone'] = telefone
        ..['dataNascimento'] = usuario.dataNascimento == null
            ? null
            : Timestamp.fromDate(usuario.dataNascimento!.toUtc())
        ..['userloggedIn'] = false
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('usuarios').doc(currentUser.uid).set(payload);
    } on FirebaseException catch (error) {
      final createdUser = _authService.currentUser;

      if (createdUser != null) {
        await createdUser.delete().catchError((_) {});
      }

      if (error.code == 'permission-denied') {
        throw FirebaseAuthException(
          code: 'permission-denied',
          message: 'Nao foi possivel gravar os dados no Firestore.',
        );
      }

      if (error.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Ja existe uma conta com este e-mail.',
        );
      }

      throw FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Erro ao salvar os dados do usuario.',
      );
    } catch (_) {
      final createdUser = _authService.currentUser;

      if (createdUser != null) {
        await createdUser.delete().catchError((_) {});
      }

      rethrow;
    }
  }
}
