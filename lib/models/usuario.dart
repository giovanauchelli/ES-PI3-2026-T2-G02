import 'package:cloud_firestore/cloud_firestore.dart';

import 'pessoa.dart';

class Usuario extends Pessoa {
  String? _id;
  String? _uid;
  String? _email;
  String? _senha;
  String? _telefone;
  int _saldo;
  bool _mfaHabilitado;
  bool _userActive;
  bool _userloggedIn;

  Usuario({
    String? id,
    String? uid,
    String? cpf,
    String? fullName,
    DateTime? dataNascimento,
    String? email,
    String? senha,
    String? telefone,
    int saldo = 0,
    bool mfaHabilitado = false,
    bool userActive = true,
    bool userloggedIn = false,
  })  : _id = id,
        _uid = uid,
        _email = email,
        _senha = senha,
        _telefone = telefone,
        _saldo = saldo,
        _mfaHabilitado = mfaHabilitado,
        _userActive = userActive,
        _userloggedIn = userloggedIn,
        super(cpf: cpf, fullName: fullName, dataNascimento: dataNascimento);

  factory Usuario.fromMap(Map<String, dynamic> map) {
    final rawDataNascimento = map['dataNascimento'];
    DateTime? dataNascimento;

    if (rawDataNascimento is Timestamp) {
      dataNascimento = rawDataNascimento.toDate();
    } else if (rawDataNascimento is DateTime) {
      dataNascimento = rawDataNascimento;
    } else if (rawDataNascimento is String && rawDataNascimento.isNotEmpty) {
      dataNascimento = DateTime.tryParse(rawDataNascimento);
    }

    return Usuario(
      id: map['id'] as String?,
      uid: map['uid'] as String?,
      cpf: map['cpf'] as String?,
      fullName: map['fullName'] as String?,
      dataNascimento: dataNascimento,
      email: map['email'] as String?,
      senha: map['senha'] as String?,
      telefone: map['telefone'] as String?,
      saldo: (map['saldo'] as num?)?.toInt() ?? 0,
      mfaHabilitado: map['mfaHabilitado'] as bool? ?? false,
      userActive: map['userActive'] as bool? ?? true,
      userloggedIn: map['userloggedIn'] as bool? ?? false,
    );
  }

  String? get id => _id;
  String? get uid => _uid;
  String? get email => _email;
  String? get senha => _senha;
  String? get telefone => _telefone;
  int get saldo => _saldo;
  bool get mfaHabilitado => _mfaHabilitado;
  bool get userActive => _userActive;
  bool get userloggedIn => _userloggedIn;

  set id(String? value) => _id = value;
  set uid(String? value) => _uid = value;
  set userActive(bool value) => _userActive = value;
  set userloggedIn(bool value) => _userloggedIn = value;
  set saldo(int value) => _saldo = value;
  set email(String? value) => _email = value;
  set senha(String? value) => _senha = value;
  set telefone(String? value) => _telefone = value;
  set mfaHabilitado(bool value) => _mfaHabilitado = value;

  String? getEmail() => _email;
  void setEmail(String? value) => _email = value;

  String? getSenha() => _senha;
  void setSenha(String? value) => _senha = value;

  String? getTelefone() => _telefone;
  void setTelefone(String? value) => _telefone = value;

  bool getMfaHabilitado() => _mfaHabilitado;
  void setMfaHabilitado(bool value) => _mfaHabilitado = value;

  Map<String, dynamic> toMap({bool includeSenha = false}) {
    final map = <String, dynamic>{
      'id': _id,
      'uid': _uid,
      'cpf': cpf,
      'fullName': fullName,
      'dataNascimento': dataNascimento == null
          ? null
          : Timestamp.fromDate(dataNascimento!.toUtc()),
      'email': _email,
      'saldo': _saldo,
      'telefone': _telefone,
      'mfaHabilitado': _mfaHabilitado,
      'userActive': _userActive,
      'userloggedIn': _userloggedIn,
    };

    if (includeSenha) {
      map['senha'] = _senha;
    }

    return map;
  }

  bool cadastrarUsuario() {
    if (!validarCpf()) return false;
    if (_email == null || _email!.trim().isEmpty) return false;
    if (_senha == null || _senha!.isEmpty) return false;
    return true;
  }

  bool autenticar([String? senhaInformada]) {
    if (_senha == null || _senha!.isEmpty) return false;
    if (senhaInformada == null) return true;
    return _senha == senhaInformada;
  }

  bool recuperarSenha([String? novaSenha]) {
    if (novaSenha == null || novaSenha.isEmpty) return false;
    _senha = novaSenha;
    return true;
  }

  void habilitarMFA() {
    _mfaHabilitado = true;
  }

  void desabilitarMFA() {
    _mfaHabilitado = false;
  }
}
