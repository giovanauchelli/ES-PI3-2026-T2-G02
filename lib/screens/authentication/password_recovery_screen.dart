import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

enum _Passo { email, instrucoes, redefinir }

class RecuperarSenhaScreen extends StatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  _Passo _passo = _Passo.email;

  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  // ── AppBar com gradiente ──────────────────────────────────────
  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () {
          if (_passo == _Passo.email) {
            Navigator.maybePop(context);
          } else if (_passo == _Passo.instrucoes) {
            setState(() => _passo = _Passo.email);
          } else {
            setState(() => _passo = _Passo.instrucoes);
          }
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Input decoration ─────────────────────────────────────────
  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  // ── Botão padrão ─────────────────────────────────────────────
  Widget _botao({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed == null ? Colors.grey : Colors.black87,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Passo 1: digitar e-mail ───────────────────────────────────
  Widget _telaEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recuperar Senha',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Digite seu Email para recuperação',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 48),
        const Text(
          'E-mail',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: _inputDecoration(hint: 'seu_email@dominio.com'),
        ),
        const SizedBox(height: 32),
        _botao(
          label: 'Prosseguir',
          onPressed: _isLoading
              ? null
              : () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    _mostrarErro('Por favor, informe seu e-mail');
                    return;
                  }
                  if (!email.contains('@')) {
                    _mostrarErro('E-mail inválido');
                    return;
                  }

                  setState(() => _isLoading = true);

                  try {
                    await AuthService().sendPasswordResetEmail(email: email);
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _passo = _Passo.instrucoes;
                      });
                    }
                  } on FirebaseAuthException catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      String mensagem;
                      switch (e.code) {
                        case 'user-not-found':
                          mensagem = 'Nenhuma conta encontrada com este e-mail';
                          break;
                        case 'invalid-email':
                          mensagem = 'E-mail inválido';
                          break;
                        case 'too-many-requests':
                          mensagem =
                              'Muitas tentativas. Tente novamente mais tarde';
                          break;
                        default:
                          mensagem = e.message ?? 'Erro ao enviar e-mail';
                      }
                      _mostrarErro(mensagem);
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      _mostrarErro('Erro inesperado. Tente novamente');
                    }
                  }
                },
        ),
      ],
    );
  }

  // ── Passo 2: instruções enviadas ─────────────────────────────
  Widget _telaInstrucoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recuperar Senha',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Verifique a sua caixa de entrada!',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              const Text(
                'Instruções Enviadas!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Enviamos um Email para '),
                    TextSpan(
                      text: _emailController.text.trim(),
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: ' com\nas instruções para redefinir sua senha',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
        const Center(
          child: Text(
            'Não recebeu? Verifique sua pasta de\nspam ou aguarde alguns minutos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ),
        const SizedBox(height: 20),
        _botao(
          label: 'Voltar ao Login',
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    try {
                      await AuthService().sendPasswordResetEmail(
                        email: _emailController.text.trim(),
                      );
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('E-mail reenviado com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        _mostrarErro('Erro ao reenviar e-mail');
                      }
                    }
                  },
            child: const Text(
              'Reenviar Email',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Passo 3: redefinir senha (não é mais necessário com Firebase,
  //    mas mantido caso queira usar no futuro) ───────────────────
  Widget _telaRedefinir() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Redefinir nova Senha',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Crie uma nova senha de acesso',
          style: TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 48),
        const Text(
          'Digite sua nova senha',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _senhaController,
          obscureText: _obscureSenha,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: _inputDecoration(
            hint: 'Nova Senha',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSenha
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black38,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Confirme sua nova senha',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmarController,
          obscureText: _obscureConfirmar,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: _inputDecoration(
            hint: 'Nova Senha',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmar
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black38,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirmar = !_obscureConfirmar),
            ),
          ),
        ),
        const SizedBox(height: 40),
        _botao(
          label: 'Enviar',
          onPressed: () {
            debugPrint('Nova senha: ${_senhaController.text}');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_passo),
              child: switch (_passo) {
                _Passo.email => _telaEmail(),
                _Passo.instrucoes => _telaInstrucoes(),
                _Passo.redefinir => _telaRedefinir(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
