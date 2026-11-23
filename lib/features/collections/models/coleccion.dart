import 'package:cloud_firestore/cloud_firestore.dart';

/// Colección personalizada de prendas (RF-05), p. ej. "Ropa de oficina".
/// Vive en `users/{uid}/colecciones/{id}`.
class Coleccion {
  const Coleccion({this.id, required this.nombre, this.descripcion = '', this.prendaIds = const [], this.fechaCreacion});

  final String? id;
  final String nombre;
  final String descripcion;
  final List<String> prendaIds;
  final DateTime? fechaCreacion;

  factory Coleccion.desdeFirestore(String id, Map<String, dynamic> datos) {
    final fecha = datos['fechaCreacion'];
    return Coleccion(
      id: id,
      nombre: datos['nombre'] is String ? (datos['nombre'] as String).trim() : 'Colección',
      descripcion: datos['descripcion'] is String ? (datos['descripcion'] as String).trim() : '',
      prendaIds: datos['prendaIds'] is List ? (datos['prendaIds'] as List).whereType<String>().toList() : const [],
      fechaCreacion: fecha is Timestamp ? fecha.toDate() : null,
    );
  }

  Map<String, dynamic> aFirestore() => {'nombre': nombre, 'descripcion': descripcion, 'prendaIds': prendaIds};
}
