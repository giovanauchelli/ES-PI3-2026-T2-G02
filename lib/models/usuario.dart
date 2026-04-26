import 'pessoa.dart';

class Usuario extends Pessoa {
  String? _uid;
  String? _email;
  String? _senha;
  int? _telefone;
  String? _cpf;
  String? _ddn;
  bool _mfaHabilitado = false;
  int _carteiraDigital = 0;

  Usuario({
    String? uid,
    super.cpf,
    super.firstName,
    super.lastName,
    super.dataNascimento,
    String? email,
    String? senha,
    String? telefone,
    bool mfaHabilitado = false,
  }) : _uid = uid,
       _email = email,
       _senha = senha,
       _telefone = telefone,
       _mfaHabilitado = mfaHabilitado;

  // Getters
  String? get uid => _uid;
  String? get email => _email;
  String? get senha => _senha;
  String? get telefone => _telefone;
  bool get mfaHabilitado => _mfaHabilitado;

  // Setters
  set uid(String? value) => _uid = value;
  set email(String? value) => _email = value;
  set senha(String? value) => _senha = value;
  set telefone(String? value) => _telefone = value;
  set mfaHabilitado(bool value) => _mfaHabilitado = value;

  /// Converte o usuário em um mapa pronto para persistência.
  /// A senha é opcional por segurança e não deve ser salva no Firestore.
  Map<String, dynamic> toMap({bool includeSenha = false}) {
    final map = <String, dynamic>{
      'uid': _uid,
      'cpf': cpf,
      'firstName': firstName,
      'lastName': lastName,
      'nomeCompleto': getNomeCompleto(),
      'dataNascimento': dataNascimento,
      'email': _email,
      'telefone': _telefone,
      'mfaHabilitado': _mfaHabilitado,
    };

    if (includeSenha) {
      map['senha'] = _senha;
    }

    return map;
  }

  /// Cadastra um novo usuário
  bool cadastrarUsuario() {
    if (_email == null || _senha == null) return false;
    if (!validarCpf()) return false;
    return true;
  }

  /// Autentica o usuário
  bool autenticar(String senhaInformada) {
    if (_senha == null) return false;
    return _senha == senhaInformada;
  }

  /// Recupera a senha do usuário
  bool recuperarSenha(String novaSenha) {
    if (novaSenha.isEmpty) return false;
    _senha = novaSenha;
    return true;
  }

  /// Habilita MFA para o usuário
  void habilitarMFA() {
    _mfaHabilitado = true;
  }
}
