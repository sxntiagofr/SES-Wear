import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/services/sesion.dart';
import '../logic/identificador_ia.dart';
import '../models/prenda.dart';

/// Resultado de analizar una foto con la IA.
class ResultadoIdentificacion {
  const ResultadoIdentificacion({required this.esPrenda, required this.prenda});

  /// `false` si la foto no muestra ropa, calzado ni accesorios.
  final bool esPrenda;
  final Prenda prenda;
}

/// Foto sin fondo que devuelve remove.bg.
class ResultadoFondo {
  const ResultadoFondo({required this.foto, required this.tipo, this.fotosGratisRestantes});

  final Uint8List foto;
  final String tipo;

  /// Fotos gratis que le quedan a la app este mes (null si no se pudo consultar).
  final int? fotosGratisRestantes;
}

/// Acceso a las prendas del armario: IA (Gemini con Firebase AI Logic),
/// quitar fondo (Cloud Function con remove.bg), Firestore y Storage.
class PrendasRepositorio {
  PrendasRepositorio({
    ServicioIA? ia,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    this._auth,
  })  : _iaInyectada = ia,
        _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final ServicioIA? _iaInyectada;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth? _auth;

  ServicioIA get _ia => _iaInyectada ?? ServicioIAFirebase.instancia;

  Future<String> _uid() => Sesion.uid(_auth);

  Future<CollectionReference<Map<String, dynamic>>> _prendas() async {
    final uid = await _uid();
    return _firestore.collection('users').doc(uid).collection('prendas');
  }

  /// Envía la foto a Gemini (Firebase AI Logic) y devuelve
  /// los atributos sugeridos para llenar el formulario.
  Future<ResultadoIdentificacion> identificar(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    await _uid();
    final datos = IdentificadorIA.normalizar(await _ia.generarJson(
      instrucciones: IdentificadorIA.instrucciones,
      pedido: TurnoIA(delUsuario: true, texto: 'Identifica esta prenda.', imagen: foto, tipoImagen: tipo),
      esquema: IdentificadorIA.esquema,
    ));
    return ResultadoIdentificacion(
      esPrenda: datos['esPrenda'] != false,
      prenda: Prenda.desdeIA(datos),
    );
  }

  /// Quita el fondo de la foto con remove.bg (Cloud Function `quitarFondo`).
  /// Devuelve un PNG con fondo transparente. Gasta 1 de las 50 fotos gratis al mes.
  Future<ResultadoFondo> quitarFondo(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    await _uid();
    final resultado = await _functions
        .httpsCallable(
          'quitarFondo',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call({
      'imagen': {'tipo': tipo, 'datos': base64Encode(foto)},
    });
    final datos = Map<String, dynamic>.from(resultado.data as Map);
    final imagen = Map<String, dynamic>.from(datos['imagen'] as Map);
    return ResultadoFondo(
      foto: base64Decode(imagen['datos'] as String),
      tipo: (imagen['tipo'] as String?) ?? 'image/png',
      fotosGratisRestantes: (datos['fotosGratisRestantes'] as num?)?.toInt(),
    );
  }

  /// Sube la foto a Storage y guarda la prenda en Firestore.
  /// Si Firestore falla, borra la foto para no dejar archivos huérfanos.
  Future<Prenda> guardar(Prenda prenda, Uint8List foto, {String tipo = 'image/jpeg'}) async {
    final uid = await _uid();
    final doc = (await _prendas()).doc();

    final extension = switch (tipo) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' || 'image/heif' => 'heic',
      _ => 'jpg',
    };
    final ref = _storage.ref('users/$uid/prendas/${doc.id}.$extension');
    await ref.putData(foto, SettableMetadata(contentType: tipo));

    try {
      final fotoUrl = await ref.getDownloadURL();
      final guardada = prenda.copyWith(id: doc.id, fotoUrl: fotoUrl);
      await doc.set({
        ...guardada.aFirestore(),
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      return guardada;
    } catch (_) {
      await ref.delete().catchError((_) {});
      rethrow;
    }
  }

  /// Guarda los cambios que hizo el usuario en una prenda (RF-02: editar).
  Future<void> actualizar(Prenda prenda) async {
    if (prenda.id == null) throw ArgumentError('La prenda no tiene id.');
    await (await _prendas()).doc(prenda.id).update(prenda.aFirestoreEditable());
  }

  /// Marca que el usuario usó estas prendas hoy: suma 1 a `vecesUsada` y
  /// actualiza `ultimoUso` (alimenta las estadísticas, RF-06).
  Future<void> registrarUso(Iterable<String> prendaIds) async {
    final coleccion = await _prendas();
    final lote = _firestore.batch();
    for (final id in prendaIds.toSet()) {
      lote.update(coleccion.doc(id), {
        'vecesUsada': FieldValue.increment(1),
        'ultimoUso': FieldValue.serverTimestamp(),
      });
    }
    await lote.commit();
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
