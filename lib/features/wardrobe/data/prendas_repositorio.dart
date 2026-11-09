import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/sesion.dart';
import '../models/prenda.dart';

/// Resultado de analizar una foto con la IA.
class ResultadoIdentificacion {
  const ResultadoIdentificacion({required this.esPrenda, required this.prenda});

  /// `false` si la foto no muestra ropa, calzado ni accesorios.
  final bool esPrenda;
  final Prenda prenda;
}

/// Acceso a las prendas del armario: IA (Cloud Function), Firestore y Storage.
class PrendasRepositorio {
  PrendasRepositorio({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<CollectionReference<Map<String, dynamic>>> _prendas() async {
    final uid = await Sesion.uid();
    return _firestore.collection('users').doc(uid).collection('prendas');
  }

  /// Envía la foto a la Cloud Function `identificarPrenda` (Gemini) y devuelve
  /// los atributos sugeridos para llenar el formulario.
  Future<ResultadoIdentificacion> identificar(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    await Sesion.uid();
    final resultado = await _functions
        .httpsCallable(
          'identificarPrenda',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call({
      'imagen': {'tipo': tipo, 'datos': base64Encode(foto)},
    });
    final datos = Map<String, dynamic>.from(resultado.data as Map);
    return ResultadoIdentificacion(
      esPrenda: datos['esPrenda'] != false,
      prenda: Prenda.desdeIA(datos),
    );
  }

  /// Sube la foto a Storage y guarda la prenda en Firestore.
  Future<Prenda> guardar(Prenda prenda, Uint8List foto, {String tipo = 'image/jpeg'}) async {
    final uid = await Sesion.uid();
    final doc = (await _prendas()).doc();

    final extension = switch (tipo) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' || 'image/heif' => 'heic',
      _ => 'jpg',
    };
    final ref = _storage.ref('users/$uid/prendas/${doc.id}.$extension');
    await ref.putData(foto, SettableMetadata(contentType: tipo));
    final fotoUrl = await ref.getDownloadURL();

    final guardada = prenda.copyWith(id: doc.id, fotoUrl: fotoUrl);
    await doc.set({
      ...guardada.aFirestore(),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    return guardada;
  }

  /// Prendas del usuario en tiempo real, de la más reciente a la más antigua.
  Stream<List<Prenda>> observar() async* {
    final coleccion = await _prendas();
    yield* coleccion.orderBy('fechaCreacion', descending: true).snapshots().map(
          (s) => s.docs.map((d) => Prenda.desdeFirestore(d.id, d.data())).toList(),
        );
  }

  /// Borra la prenda y su foto.
  Future<void> eliminar(Prenda prenda) async {
    if (prenda.id == null) return;
    await (await _prendas()).doc(prenda.id).delete();
    if (prenda.fotoUrl != null) {
      try {
        await _storage.refFromURL(prenda.fotoUrl!).delete();
      } catch (_) {
        // Si la foto ya no existe, no pasa nada.
      }
    }
  }
}
