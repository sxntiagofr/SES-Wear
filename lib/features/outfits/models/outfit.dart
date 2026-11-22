import 'package:cloud_firestore/cloud_firestore.dart';

/// Ocasiones y climas del generador. Deben coincidir con `functions/src/outfits.js`.
class OpcionesOutfit {
  OpcionesOutfit._();

  static const ocasiones = ['casual', 'universidad', 'trabajo', 'deportivo', 'fiesta', 'formal'];
  static const climas = ['cualquiera', 'calor', 'frío', 'lluvia'];

  static String etiquetaOcasion(String o) => switch (o) {
        'universidad' => 'U',
        'formal' => 'Formal / entrevista',
        _ => o.isEmpty ? o : o[0].toUpperCase() + o.substring(1),
      };

  static String etiquetaClima(String c) => switch (c) {
        'cualquiera' => 'Cualquier clima',
        _ => c[0].toUpperCase() + c.substring(1),
      };
}

/// Un outfit: combinación de prendas del armario.
///
/// Los guardados viven en `users/{uid}/outfits/{outfitId}` (RF-03).
/// `origen`: `local` (generador de la app), `ia` (Gemini) o `manual`.
class Outfit {
  const Outfit({
    this.id,
    required this.nombre,
    required this.prendaIds,
    this.ocasion = 'casual',
    this.clima = 'cualquiera',
    this.explicacion = '',
    this.favorito = false,
    this.calificacion = 0,
    this.origen = 'local',
    this.fechaCreacion,
  });

  final String? id;
  final String nombre;
  final List<String> prendaIds;
  final String ocasion;
  final String clima;
  final String explicacion;
  final bool favorito;

  /// De 0 (sin calificar) a 5 estrellas.
  final int calificacion;
  final String origen;
  final DateTime? fechaCreacion;

  /// Identifica la combinación sin importar el orden de las prendas.
  String get clave => (List.of(prendaIds)..sort()).join('|');

  static String _texto(dynamic v) => v is String ? v.trim() : '';

  factory Outfit.desdeFirestore(String id, Map<String, dynamic> datos) {
    final fecha = datos['fechaCreacion'];
    final calificacion = datos['calificacion'];
    final origen = _texto(datos['origen']);
    return Outfit(
      id: id,
      nombre: _texto(datos['nombre']).isEmpty ? 'Outfit' : _texto(datos['nombre']),
      prendaIds: datos['prendaIds'] is List ? (datos['prendaIds'] as List).whereType<String>().toList() : const [],
      ocasion: _texto(datos['ocasion']).isEmpty ? 'casual' : _texto(datos['ocasion']),
      clima: _texto(datos['clima']).isEmpty ? 'cualquiera' : _texto(datos['clima']),
      explicacion: _texto(datos['explicacion']),
      favorito: datos['favorito'] == true,
      calificacion: calificacion is num ? calificacion.toInt().clamp(0, 5) : 0,
      origen: ['local', 'ia', 'manual'].contains(origen) ? origen : 'local',
      fechaCreacion: fecha is Timestamp ? fecha.toDate() : null,
    );
  }

  /// Datos para Firestore (la fecha la pone el repositorio).
  Map<String, dynamic> aFirestore() => {
        'nombre': nombre,
        'prendaIds': prendaIds,
        'ocasion': ocasion,
        'clima': clima,
        'explicacion': explicacion,
        'favorito': favorito,
        'calificacion': calificacion,
        'origen': origen,
      };

  Outfit copyWith({String? id, String? nombre, bool? favorito, int? calificacion}) => Outfit(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        prendaIds: prendaIds,
        ocasion: ocasion,
        clima: clima,
        explicacion: explicacion,
        favorito: favorito ?? this.favorito,
        calificacion: calificacion ?? this.calificacion,
        origen: origen,
        fechaCreacion: fechaCreacion,
      );
}
