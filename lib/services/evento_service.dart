import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/evento.dart';

class EventoService {
  EventoService({
    FirebaseFirestore? firestore,
    String collectionPath = 'eventos',
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _collectionPath = collectionPath;

  final FirebaseFirestore _firestore;
  final String _collectionPath;

  Future<List<Evento>> listarEventos() async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .orderBy('data', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      return Evento.fromFirestore(doc.id, doc.data());
    }).toList();
  }
}