import 'package:flutter/material.dart';
import '../home/home_screen.dart';

// ─────────────────────────────────────────────
// TELA: Saldo Confirmado
// ─────────────────────────────────────────────
class SaldoConfirmadoScreen extends StatelessWidget {
  final double valorCreditado;
  final double saldoAnterior;
  final double novoSaldo;

  const SaldoConfirmadoScreen({
    super.key,
    required this.valorCreditado,
    required this.saldoAnterior,
    required this.novoSaldo,
  });

  String _formatReal(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _dataAtual() {
    final now = DateTime.now();
    final meses = [
      '',
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    final hora = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '${now.day} ${meses[now.month]} ${now.year} - $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // Gradiente topo
          const SizedBox(height: 20),
          Container(
            color: const Color.fromARGB(255, 255, 255, 255),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 2,
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
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Ícone de sucesso
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4CAF50), width: 3),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF4CAF50),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  const Text(
                    'Saldo adicionado!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Resumo
                  _LinhaResumo(
                    label: 'Valor Creditado',
                    valor: _formatReal(valorCreditado),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Data',
                    valor: _dataAtual(),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Saldo anterior',
                    valor: _formatReal(saldoAnterior),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Novo saldo',
                    valor: _formatReal(novoSaldo),
                    valorColor: const Color(0xFF6C63FF),
                    bold: true,
                  ),
                  const SizedBox(height: 40),

                  // Botão voltar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(
                            context, (route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.black87, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Voltar para a Carteira',
                        style: TextStyle(
                          fontSize: 15,
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

// ── Widget compartilhado: Linha de resumo ─────────────────────
class _LinhaResumo extends StatelessWidget {
  final String label;
  final String valor;
  final Color valorColor;
  final bool bold;

  const _LinhaResumo({
    required this.label,
    required this.valor,
    required this.valorColor,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            color: valorColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}