import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/claves.dart';
import '../../../core/ia/servicio_ia.dart';
import '../../../core/services/sesion.dart';
import '../../../core/utils/imagenes.dart';
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

/// Error al quitar el fondo, con un mensaje listo para mostrar.
class ErrorFondo implements Exception {
  const ErrorFondo(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
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

  ServicioIA get _ia => _iaInyectada ?? servicioIAPorDefecto;

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

  /// Quita el fondo de la foto con remove.bg y devuelve un PNG con fondo
  /// transparente. Con `REMOVE_BG_API_KEY` en claves.json llama a remove.bg
  /// directamente; si no, usa la Cloud Function `quitarFondo` (plan Blaze).
  Future<ResultadoFondo> quitarFondo(Uint8List foto, {String tipo = 'image/jpeg'}) async {
    await _uid();
    if (Claves.hayRemoveBg) return _quitarFondoDirecto(foto, tipo);
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

  /// remove.bg directo (plan gratis: 50 fotos al mes en tamaño "preview").
  Future<ResultadoFondo> _quitarFondoDirecto(Uint8List foto, String tipo) async {
    final pedido = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'))
      ..headers['X-Api-Key'] = Claves.removeBg
      ..fields['size'] = 'preview'
      ..fields['format'] = 'png'
      ..files.add(http.MultipartFile.fromBytes('image_file', foto, filename: 'prenda.${tipo.split('/').last}'));
    final http.Response r;
    try {
      r = await http.Response.fromStream(await pedido.send().timeout(const Duration(seconds: 60)));
    } on TimeoutException {
      throw const ErrorFondo('remove.bg tardó demasiado. Inténtalo de nuevo.');
    } catch (_) {
      throw const ErrorFondo('No se pudo conectar con remove.bg. Revisa tu conexión.');
    }
    if (r.statusCode == 200) {
      return ResultadoFondo(foto: r.bodyBytes, tipo: 'image/png');
    }
    debugPrint('[remove.bg] ${r.statusCode}: ${r.body}');
    throw ErrorFondo(switch (r.statusCode) {
      400 when r.body.contains('foreground') =>
        'No se encontró la prenda en la foto para quitarle el fondo. Prueba con otra foto.',
      400 => 'remove.bg no pudo procesar la foto.',
      401 || 403 => 'La clave de remove.bg (REMOVE_BG_API_KEY) no es válida. Revisa claves.json.',
      402 => 'Se acabaron las fotos gratis para quitar el fondo este mes. Guarda la prenda con la foto original.',
      429 => 'Demasiadas fotos al mismo tiempo. Espera un momento e inténtalo de nuevo.',
      _ => 'El servicio para quitar el fondo no está disponible ahora. Inténtalo más tarde.',
    });
  }

  /// Guarda la prenda en Firestore (`users/{uid}/prendas/{id}`) con su foto.
  ///
  /// La foto se sube a Firebase Storage; si Storage no está disponible (en el
  /// plan gratuito Spark los proyectos nuevos no tienen Storage), se guarda
  /// reducida dentro del mismo documento de Firestore.
  Future<Prenda> guardar(Prenda prenda, Uint8List foto, {String tipo = 'image/jpeg'}) async {
    final uid = await _uid();
    final doc = (await _prendas()).doc();
    final comprimida = comprimirFoto(foto, tipo: tipo);

    String fotoUrl;
    Reference? ref;
    try {
      final extension = comprimida.tipo == 'image/png' ? 'png' : 'jpg';
      ref = _storage.ref('users/$uid/prendas/${doc.id}.$extension');
      await ref
          .putData(comprimida.bytes, SettableMetadata(contentType: comprimida.tipo))
          .timeout(const Duration(seconds: 20));
      fotoUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Storage no disponible ($e); la foto se guarda en Firestore.');
      ref = null;
      fotoUrl = comprimida.comoDataUrl;
    }

    final guardada = prenda.copyWith(id: doc.id, fotoUrl: fotoUrl);
    try {
      await _escribir(doc.set({
        ...guardada.aFirestore(),
        'fechaCreacion': FieldValue.serverTimestamp(),
      }));
      return guardada;
    } catch (_) {
      await ref?.delete().catchError((_) {});
      rethrow;
    }
  }

  /// Firestore guarda primero en el celular y luego sincroniza con el
  /// servidor. Si el servidor tarda (mala conexión), no se deja al usuario
  /// esperando: el dato ya quedó guardado y se sube solo.
  static Future<void> _escribir(Future<void> escritura) async {
    try {
      await escritura.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      debugPrint('Firestore: la escritura se sincronizará cuando haya conexión.');
    }
  }

  /// Guarda los cambios que hizo el usuario en una prenda (RF-02: editar).
  Future<void> actualizar(Prenda prenda) async {
    if (prenda.id == null) throw ArgumentError('La prenda no tiene id.');
    await _escribir((await _prendas()).doc(prenda.id).update(prenda.aFirestoreEditable()));
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
    if (prenda.fotoUrl != null && !prenda.fotoUrl!.startsWith('data:')) {
      try {
        await _storage.refFromURL(prenda.fotoUrl!).delete();
      } catch (_) {
        // Si la foto ya no existe, no pasa nada.
      }
    }
  }
}
