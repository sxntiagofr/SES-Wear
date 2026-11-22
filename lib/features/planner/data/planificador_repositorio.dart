import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/sesion.dart';
import '../models/plan_dia.dart';

/// Calendario de atuendos: `users/{uid}/planificador/{AAAA-MM-DD}` (RF-07).
class PlanificadorRepositorio {
  PlanificadorRepositorio({FirebaseFirestore? firestore, this._auth})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  Future<CollectionReference<Map<String, dynamic>>> _planes() async {
    final uid = await Sesion.uid(_auth);
    return _firestore.collection('users').doc(uid).collection('planificador');
  }

  /// Planes desde hace un mes en adelante, indexados por fecha.
  Stream<Map<String, PlanDia>> observar({DateTime? desde}) async* {
    final inicio = PlanDia.claveDe((desde ?? DateTime.now()).subtract(const Duration(days: 31)));
    final coleccion = await _planes();
    yield* coleccion.where('fecha', isGreaterThanOrEqualTo: inicio).snapshots().map((s) => {
          for (final d in s.docs) d.id: PlanDia.desdeFirestore(d.id, d.data()),
        });
  }

  Future<void> asignar(PlanDia plan) async => (await _planes())
      .doc(plan.fecha)
      .set({...plan.aFirestore(), 'actualizado': FieldValue.serverTimestamp()});

  Future<void> quitar(String fecha) async => (await _planes()).doc(fecha).delete();
}
