import 'package:cloud_firestore/cloud_firestore.dart';

/// Opciones cerradas que usa la IA y los filtros del armario.
/// Deben coincidir con `functions/src/identificador.js`.
class OpcionesPrenda {
  OpcionesPrenda._();

  static const tipos = ['superior', 'inferior', 'calzado', 'accesorio', 'enterizo', 'abrigo'];
  static const formalidades = ['casual', 'deportivo', 'semiformal', 'formal', 'fiesta'];
  static const estaciones = ['calor', 'frío', 'lluvia', 'todo el año'];
}

/// Una prenda del armario del usuario.
///
/// En Firestore vive en `users/{uid}/prendas/{prendaId}` y su foto en Storage,
/// en `users/{uid}/prendas/{prendaId}.jpg` (ver docs/arquitectura.md).
class Prenda {
  const Prenda({
    this.id,
    required this.nombre,
    required this.tipo,
    this.categoria = '',
    this.colorPrimario = '',
    this.colorSecundario = '',
    this.tela = '',
    this.estilo = '',
    this.formalidad = 'casual',
    this.estacion = 'todo el año',
    this.etiquetas = const [],
    this.fotoUrl,
    this.vecesUsada = 0,
    this.identificadaPorIA = false,
    this.fechaCreacion,
  });

  final String? id;
  final String nombre;
  final String tipo;
  final String categoria;
  final String colorPrimario;
  final String colorSecundario;
  final String tela;
  final String estilo;
  final String formalidad;
  final String estacion;
  final List<String> etiquetas;
  final String? fotoUrl;
  final int vecesUsada;
  final bool identificadaPorIA;
  final DateTime? fechaCreacion;

  static String _texto(dynamic v) => v is String ? v.trim() : '';

  static String _deLista(dynamic v, List<String> opciones, String porDefecto) {
    final valor = _texto(v);
    return opciones.contains(valor) ? valor : porDefecto;
  }

  static List<String> _lista(dynamic v) =>
      v is List ? v.whereType<String>().where((e) => e.trim().isNotEmpty).toList() : const [];

  /// Atributos que devuelve la Cloud Function `identificarPrenda`.
  factory Prenda.desdeIA(Map<String, dynamic> datos) {
    return Prenda(
      nombre: _texto(datos['nombre']),
      tipo: _deLista(datos['tipo'], OpcionesPrenda.tipos, 'superior'),
      categoria: _texto(datos['categoria']),
      colorPrimario: _texto(datos['colorPrimario']),
      colorSecundario: _texto(datos['colorSecundario']),
      tela: _texto(datos['tela']),
      estilo: _texto(datos['estilo']),
      formalidad: _deLista(datos['formalidad'], OpcionesPrenda.formalidades, 'casual'),
      estacion: _deLista(datos['estacion'], OpcionesPrenda.estaciones, 'todo el año'),
      etiquetas: _lista(datos['etiquetas']),
      identificadaPorIA: true,
    );
  }

  factory Prenda.desdeFirestore(String id, Map<String, dynamic> datos) {
    final fecha = datos['fechaCreacion'];
    return Prenda(
      id: id,
      nombre: _texto(datos['nombre']),
      tipo: _deLista(datos['tipo'], OpcionesPrenda.tipos, 'superior'),
      categoria: _texto(datos['categoria']),
      colorPrimario: _texto(datos['colorPrimario']),
      colorSecundario: _texto(datos['colorSecundario']),
      tela: _texto(datos['tela']),
      estilo: _texto(datos['estilo']),
      formalidad: _deLista(datos['formalidad'], OpcionesPrenda.formalidades, 'casual'),
      estacion: _deLista(datos['estacion'], OpcionesPrenda.estaciones, 'todo el año'),
      etiquetas: _lista(datos['etiquetas']),
      fotoUrl: datos['fotoUrl'] as String?,
      vecesUsada: (datos['vecesUsada'] as num?)?.toInt() ?? 0,
      identificadaPorIA: datos['identificadaPorIA'] == true,
      fechaCreacion: fecha is Timestamp ? fecha.toDate() : null,
    );
  }

  /// Campos que se guardan en Firestore (la fecha la pone el repositorio).
  Map<String, dynamic> aFirestore() => {
        'nombre': nombre,
        'tipo': tipo,
        'categoria': categoria,
        'colorPrimario': colorPrimario,
        'colorSecundario': colorSecundario,
        'tela': tela,
        'estilo': estilo,
        'formalidad': formalidad,
        'estacion': estacion,
        'etiquetas': etiquetas,
        'fotoUrl': fotoUrl,
        'vecesUsada': vecesUsada,
        'identificadaPorIA': identificadaPorIA,
      };

  Prenda copyWith({
    String? id,
    String? nombre,
    String? tipo,
    String? categoria,
    String? colorPrimario,
    String? colorSecundario,
    String? tela,
    String? estilo,
    String? formalidad,
    String? estacion,
    List<String>? etiquetas,
    String? fotoUrl,
  }) {
    return Prenda(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      colorPrimario: colorPrimario ?? this.colorPrimario,
      colorSecundario: colorSecundario ?? this.colorSecundario,
      tela: tela ?? this.tela,
      estilo: estilo ?? this.estilo,
      formalidad: formalidad ?? this.formalidad,
      estacion: estacion ?? this.estacion,
      etiquetas: etiquetas ?? this.etiquetas,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      vecesUsada: vecesUsada,
      identificadaPorIA: identificadaPorIA,
      fechaCreacion: fechaCreacion,
    );
  }
}
