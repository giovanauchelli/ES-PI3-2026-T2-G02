import 'package:flutter/material.dart';

class PerguntasTab extends StatefulWidget {
  const PerguntasTab({super.key});

  @override
  State<PerguntasTab> createState() => _PerguntasTabState();
}

class _PerguntasTabState extends State<PerguntasTab> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (_, i) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _PerguntaItem(
                iniciais: 'PD',
                nome: 'Paula Domingues',
                pergunta: 'Qual é o modelo de receita principal?',
              ),
            ),
          ),
        ),
        // Campo de envio
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFD1CEFF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('AN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C63FF))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enviar Mensagem',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: Colors.black38),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF6C63FF), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                child: const Text('Enviar',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerguntaItem extends StatelessWidget {
  final String iniciais;
  final String nome;
  final String pergunta;

  const _PerguntaItem({
    required this.iniciais,
    required this.nome,
    required this.pergunta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFD1CEFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(iniciais,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 2),
              Text(pergunta,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Ver resposta de AgroSense',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}