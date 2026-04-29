import 'package:flutter/material.dart';

import '../../services/password_recovery_service.dart';

class RedefinirNovaSenhaScreen extends StatefulWidget {
  const RedefinirNovaSenhaScreen({
    super.key,
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  @override
  State<RedefinirNovaSenhaScreen> createState() =>
      _RedefinirNovaSenhaScreenState();
}

class _RedefinirNovaSenhaScreenState extends State<RedefinirNovaSenhaScreen> {
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final PasswordRecoveryService _passwordRecoveryService =
      PasswordRecoveryService();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(_atualizarEstadoSenhas);
    _confirmarController.addListener(_atualizarEstadoSenhas);
  }

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _atualizarEstadoSenhas() {
    if (_senhaController.text.isEmpty && _confirmarController.text.isNotEmpty) {
      _confirmarController.clear();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _enviar() async {
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarController.text;

    if (senha.isEmpty || confirmarSenha.isEmpty) {
      _mostrarMensagem('Preencha os dois campos de senha.', isError: true);
      return;
    }

    if (senha.length < 6) {
      _mostrarMensagem(
        'A nova senha deve ter pelo menos 6 caracteres.',
        isError: true,
      );
      return;
    }

    if (senha != confirmarSenha) {
      _mostrarMensagem('As senhas nao coincidem.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _passwordRecoveryService.resetPassword(
        email: widget.email,
        code: widget.code,
        newPassword: senha,
      );

      if (!mounted) return;
      _mostrarMensagem('Senha redefinida com sucesso.');
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      _mostrarMensagem(_mensagemErro(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarMensagem(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
      ),
    );
  }

  String _mensagemErro(Object error) {
    final texto = error.toString().toLowerCase();

    if (texto.contains('permission-denied')) {
      return 'O codigo informado esta incorreto.';
    }

    if (texto.contains('deadline-exceeded')) {
      return 'O codigo expirou. Solicite um novo envio.';
    }

    if (texto.contains('not-found')) {
      return 'Nao encontramos uma solicitacao ativa para este e-mail.';
    }

    if (texto.contains('failed-precondition')) {
      return 'Este codigo nao pode mais ser usado. Solicite outro.';
    }

    return 'Nao foi possivel redefinir a senha agora.';
  }

  bool get _senhaFoiPreenchida => _senhaController.text.isNotEmpty;

  Color? get _corBordaSenhas {
    if (!_senhaFoiPreenchida || _confirmarController.text.isEmpty) {
      return null;
    }

    return _senhaController.text == _confirmarController.text
        ? Colors.green
        : Colors.red;
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
    Color? enabledBorderColor,
    Color? focusedBorderColor,
  }) {
    final borderColor = enabledBorderColor ?? const Color(0xFFDDDDDD);
    final activeBorderColor =
        focusedBorderColor ?? enabledBorderColor ?? const Color(0xFF6C63FF);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: activeBorderColor, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF6C63FF),
                          Color(0xFFE040FB),
                          Color(0xFFFF6B6B),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size: 22,
                    ),
                    onPressed: _isLoading ? null : () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Redefinir nova Senha',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crie uma nova senha para ${widget.email}',
                    style: const TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 48),
                  const Text(
                    'Digite sua nova senha',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _senhaController,
                    obscureText: _obscureSenha,
                    enabled: !_isLoading,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    decoration: _inputDecoration(
                      hint: 'Nova Senha',
                      enabledBorderColor: _corBordaSenhas,
                      focusedBorderColor: _corBordaSenhas,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureSenha = !_obscureSenha),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Confirme sua nova senha',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmarController,
                    obscureText: _obscureConfirmar,
                    enabled: !_isLoading,
                    readOnly: !_senhaFoiPreenchida,
                    onTap: () {
                      if (_senhaFoiPreenchida || _isLoading) return;

                      _mostrarMensagem(
                        'Preencha a senha antes de confirmar.',
                        isError: true,
                      );
                    },
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    decoration: _inputDecoration(
                      hint: 'Nova Senha',
                      enabledBorderColor: _corBordaSenhas,
                      focusedBorderColor: _corBordaSenhas,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmar
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmar = !_obscureConfirmar,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _enviar,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isLoading ? Colors.black26 : Colors.black87,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.black87,
                                ),
                              ),
                            )
                          : const Text(
                              'Enviar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
