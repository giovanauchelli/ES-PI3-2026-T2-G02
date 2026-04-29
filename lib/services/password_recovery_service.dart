import 'package:cloud_functions/cloud_functions.dart';

class PasswordRecoveryService {
  PasswordRecoveryService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> sendRecoveryCode({required String email}) async {
    final callable = _functions.httpsCallable(
      'solicitarCodigoRecuperacaoSenha',
    );

    await callable.call(<String, dynamic>{
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final callable = _functions.httpsCallable('redefinirSenhaComCodigo');

    await callable.call(<String, dynamic>{
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }
}
