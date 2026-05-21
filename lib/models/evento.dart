import 'package:cloud_firestore/cloud_firestore.dart';

class Evento {
  final String uid;
  final String titulo;
  final String descricao;
  final String tipo; // 'atualizacao' ou 'evento'
  final DateTime data;

  const Evento({
    required this.uid,
    required this.titulo,
    required this.descricao,
    required this.tipo,
    required this.data,
  });

  factory Evento.fromFirestore(String uid, Map<String, dynamic> data) {
    return Evento(
      uid: uid,
      titulo: (data['titulo'] ?? '') as String,
      descricao: (data['descricao'] ?? '') as String,
      tipo: (data['tipo'] ?? 'evento') as String,
      data: (data['data'] as Timestamp).toDate(),
    );
  }
}