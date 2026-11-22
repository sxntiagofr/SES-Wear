import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/sesion.dart';
import '../models/coleccion.dart';

/// Colecciones del usuario: `users/{uid}/colecciones` (RF-05).
class ColeccionesRepositorio {
  ColeccionesRepositorio({FirebaseFirestore? firestore, this._auth})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  Future<CollectionReference<Map<String, dynamic>>> _colecciones() async {
    final uid = await Sesion.uid(_auth);
    return _firestore.collection('users').doc(uid).collection('colecciones');
  }

  Stream<List<Coleccion>> observar() async* {
    final coleccion = await _colecciones();
    yield* coleccion.orderBy('nombre').snapshots().map(
          (s) => s.docs.map((d) => Coleccion.desdeFirestore(d.id, d.data())).toList(),
        );
  }

  Future<Coleccion> crear(String nombre, {String descripcion = ''}) async {
    final nueva = Coleccion(nombre: nombre.trim(), descripcion: descripcion.trim());
    final doc = (await _colecciones()).doc();
    await doc.set({...nueva.aFirestore(), 'fechaCreacion': FieldValue.serverTimestamp()});
    return Coleccion(id: doc.id, nombre: nueva.nombre, descripcion: nueva.descripcion);
  }

  Future<void> actualizar(Coleccion coleccion) async =>
      (await _colecciones()).doc(coleccion.id).update(coleccion.aFirestore());

  Future<void> eliminar(String id) async => (await _colecciones()).doc(id).delete();
}
