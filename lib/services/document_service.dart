import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/documento.dart';

class DocumentoService {
  final _db = FirebaseFirestore.instance;

  /// Busca os documentos públicos de uma startup.
  /// Os documentos estão no mapa embutido `documentos` no documento da startup.
  /// Fallback para sub-coleção caso a estrutura mude.
  Future<List<Documento>> getDocumentos(String startupId) async {
    final startupSnap = await _db.collection('startups').doc(startupId).get();

    // Embedded map (current structure)
    final docMap = startupSnap.data()?['documentos'];
    if (docMap is Map && docMap.isNotEmpty) {
      return docMap.entries
          .where((e) => e.value is Map)
          .map((e) => Documento.fromFirestore(
                e.key.toString(),
                Map<String, dynamic>.from(e.value as Map),
              ))
          .toList();
    }

    // Fallback: sub-collection
    final snap = await _db
        .collection('startups')
        .doc(startupId)
        .collection('documentos')
        .get();

    return snap.docs
        .map((doc) => Documento.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}