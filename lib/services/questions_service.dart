import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pergunta.dart';

class PerguntaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Pergunta>> getPerguntasStream(String idStartup) {
    return _firestore
        .collection('perguntas')
        .where('idStartup', isEqualTo: idStartup)
        .snapshots()
        .map((snapshot) {
          final lista = snapshot.docs
              .map((doc) => Pergunta.fromFirestore(doc.id, doc.data()))
              .where((p) => !p.privada)
              .toList();

          lista.sort((a, b) => a.dataEnvio.compareTo(b.dataEnvio));

          return lista;
        });
  }

  Future<void> enviarPergunta(Pergunta pergunta) async {
    await _firestore.collection('perguntas').add(pergunta.toMap());
  }
}