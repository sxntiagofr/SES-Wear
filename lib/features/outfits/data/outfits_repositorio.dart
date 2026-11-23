import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/services/sesion.dart';
import '../../wardrobe/models/prenda.dart';
import '../logic/outfits_ia.dart';
import '../models/outfit.dart';

/// Outfits guardados (`users/{uid}/outfits`) y generador con IA (Gemini con
/// Firebase AI Logic).
class OutfitsRepositorio {
  OutfitsRepositorio({FirebaseFirestore? firestore, ServicioIA? ia, this._auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _iaInyectada = ia;

  final FirebaseFirestore _firestore;
  final ServicioIA? _iaInyectada;
  final FirebaseAuth? _auth;

  ServicioIA get _ia => _iaInyectada ?? servicioIAPorDefecto;

  Future<CollectionReference<Map<String, dynamic>>> _outfits() async {
    final uid = await Sesion.uid(_auth);
    return _firestore.collection('users').doc(uid).collection('outfits');
  }

  /// Outfits guardados, del más reciente al más antiguo.
  Stream<List<Outfit>> observar() async* {
    final coleccion = await _outfits();
    yield* coleccion.orderBy('fechaCreacion', descending: true).snapshots().map(
          (s) => s.docs.map((d) => Outfit.desdeFirestore(d.id, d.data())).toList(),
        );
  }

  Future<Outfit> guardar(Outfit outfit) async {
    final doc = (await _outfits()).doc();
    await doc.set({...outfit.aFirestore(), 'fechaCreacion': FieldValue.serverTimestamp()});
    return outfit.copyWith(id: doc.id);
  }

  Future<void> marcarFavorito(String id, bool favorito) async =>
      (await _outfits()).doc(id).update({'favorito': favorito});

  Future<void> calificar(String id, int estrellas) async =>
      (await _outfits()).doc(id).update({'calificacion': estrellas.clamp(0, 5)});

  Future<void> eliminar(String id) async => (await _outfits()).doc(id).delete();

  /// Pide combinaciones a Gemini (Firebase AI Logic) con las prendas dadas
  /// (todo el armario o solo una colección). `excluir`: combinaciones ya
  /// mostradas, para "pedir alternativas".
  Future<List<Outfit>> generarConIA({
    required List<Prenda> prendas,
    required String ocasion,
    String clima = 'cualquiera',
    int cantidad = 3,
    List<List<String>> excluir = const [],
  }) async {
    await Sesion.uid(_auth);
    final conId = prendas.where((p) => p.id != null).toList();
    if (conId.length < 2) {
      throw const ErrorIA('Necesitas al menos 2 prendas para armar un outfit.');
    }
    final datos = await _ia.generarJson(
      instrucciones: OutfitsIA.instrucciones,
      pedido: TurnoIA(
        delUsuario: true,
        texto: OutfitsIA.pedido(prendas: conId, ocasion: ocasion, clima: clima, cantidad: cantidad, excluir: excluir),
      ),
      esquema: OutfitsIA.esquema,
      temperatura: 0.7,
    );
    return OutfitsIA.normalizar(
      datos,
      idsValidos: conId.map((p) => p.id!).toSet(),
      ocasion: ocasion,
      clima: clima,
      excluir: excluir,
      cantidad: cantidad,
    );
  }
}
