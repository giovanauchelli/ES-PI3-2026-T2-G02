class User {
  String? _uid;
  String? _fullname;
  String? _email;
  String? _password;
  String? _phone;
  String? _cpf;
  String? _ddn;
  bool _mfaEnabled = false;
  int _carteiraDigital = 0;
  bool _isActive = true;

  User({
    String? uid,
    String? fullname,
    String? email,
    String? password,
    String? phone,
    String? cpf,
    String? ddn,
    bool mfaEnabled = false,
  }) :
       _uid = uid,
       _fullname = fullname,
       _email = email,
       _password = password,
       _phone = phone,
       _cpf = cpf,
       _ddn = ddn,
       _mfaEnabled = mfaEnabled;

  // Getters
  String? get uid => _uid;
  String? get fullname => _fullname;
  String? get email => _email;
  String? get password => _password;
  String? get phone => _phone;
  String? get cpf => _cpf;
  String? get ddn => _ddn;
  bool get mfaEnabled => _mfaEnabled;

  // Setters
  set 
}