import 'package:cloud_firestore/cloud_firestore.dart';

/// Opciones cerradas que usa la IA y los filtros del armario.
/// Deben coincidir con `functions/src/identificador.js` y `firestore.rules`.
class OpcionesPrenda {
  OpcionesPrenda._();

  static const tipos = ['superior', 'inferior', 'calzado', 'accesorio', 'enterizo', 'abrigo'];
  static const formalidades = ['casual', 'deportivo', 'semiformal', 'formal', 'fiesta'];
  static const estaciones = ['calor', 'frío', 'lluvia', 'todo el año'];
}

/// Una prenda del armario del usuario.
///
/// En Firestore vive en `users/{uid}/prendas/{prendaId}` y su foto en Storage,
/// en `users/{uid}/prendas/{prendaId}.jpg` (ver docs/base-de-datos.md).
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
    this.precio,
    this.ultimoUso,
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

  /// Lo que costó la prenda en pesos (opcional). Sirve para el costo por uso (RF-06).
  final double? precio;

  /// Última vez que el usuario marcó que la usó.
  final DateTime? ultimoUso;
  final DateTime? fechaCreacion;

  /// Costo por uso: precio ÷ veces usada (null si no hay precio o nunca se usó).
  double? get costoPorUso => (precio == null || vecesUsada == 0) ? null : precio! / vecesUsada;

  static String _texto(dynamic v) => v is String ? v.trim() : '';

  static String _deLista(dynamic v, List<String> opciones, String porDefecto) {
    final valor = _texto(v);
    return opciones.contains(valor) ? valor : porDefecto;
  }

  /// Número entero tolerante: acepta 3, 3.0 o "3"; cualquier otra cosa es 0.
  static int _entero(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double? _decimal(dynamic v) {
    final n = v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim()) : null);
    return (n == null || n < 0) ? null : n;
  }

  static DateTime? _fecha(dynamic v) => v is Timestamp ? v.toDate() : null;

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

  /// Lee un documento de Firestore sin fallar si algún campo viene con otro tipo:
  /// un documento mal formado no debe romper todo el armario.
  factory Prenda.desdeFirestore(String id, Map<String, dynamic> datos) {
    final foto = datos['fotoUrl'];
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
      fotoUrl: foto is String && foto.isNotEmpty ? foto : null,
      vecesUsada: _entero(datos['vecesUsada']),
      identificadaPorIA: datos['identificadaPorIA'] == true,
      precio: _decimal(datos['precio']),
      ultimoUso: _fecha(datos['ultimoUso']),
      fechaCreacion: _fecha(datos['fechaCreacion']),
    );
  }

  /// Campos que el usuario puede editar (no toca vecesUsada, ultimoUso ni la foto).
  Map<String, dynamic> aFirestoreEditable() => {
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
        'precio': precio,
      };

  /// Campos de una prenda nueva (la fecha la pone el repositorio).
  Map<String, dynamic> aFirestore() => {
        ...aFirestoreEditable(),
        'fotoUrl': fotoUrl,
        'vecesUsada': vecesUsada,
        'identificadaPorIA': identificadaPorIA,
      };

  /// Copia con cambios. Para borrar el precio usa `quitarPrecio: true`.
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
    int? vecesUsada,
    double? precio,
    bool quitarPrecio = false,
    DateTime? ultimoUso,
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
      vecesUsada: vecesUsada ?? this.vecesUsada,
      identificadaPorIA: identificadaPorIA,
      precio: quitarPrecio ? null : (precio ?? this.precio),
      ultimoUso: ultimoUso ?? this.ultimoUso,
      fechaCreacion: fechaCreacion,
    );
  }
}

/// Búsqueda y filtros del armario (RF-02). Es inmutable: cada cambio crea uno nuevo.
class FiltroPrendas {
  const FiltroPrendas({this.texto = '', this.tipo, this.color, this.estacion, this.formalidad});

  final String texto;
  final String? tipo;
  final String? color;
  final String? estacion;
  final String? formalidad;

  bool get activo =>
      texto.trim().isNotEmpty || tipo != null || color != null || estacion != null || formalidad != null;

  /// Cuántos filtros (sin contar el texto) están activos.
  int get cantidad => [tipo, color, estacion, formalidad].whereType<String>().length;

  FiltroPrendas conTexto(String v) => FiltroPrendas(
      texto: v, tipo: tipo, color: color, estacion: estacion, formalidad: formalidad);
  FiltroPrendas conTipo(String? v) => FiltroPrendas(
      texto: texto, tipo: v, color: color, estacion: estacion, formalidad: formalidad);
  FiltroPrendas conColor(String? v) => FiltroPrendas(
      texto: texto, tipo: tipo, color: v, estacion: estacion, formalidad: formalidad);
  FiltroPrendas conEstacion(String? v) => FiltroPrendas(
      texto: texto, tipo: tipo, color: color, estacion: v, formalidad: formalidad);
  FiltroPrendas conFormalidad(String? v) => FiltroPrendas(
      texto: texto, tipo: tipo, color: color, estacion: estacion, formalidad: v);

  static String _normalizar(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .trim();

  bool acepta(Prenda p) {
    if (tipo != null && p.tipo != tipo) return false;
    if (formalidad != null && p.formalidad != formalidad) return false;
    // "todo el año" sirve para cualquier estación.
    if (estacion != null && p.estacion != estacion && p.estacion != 'todo el año') return false;
    if (color != null) {
      final c = _normalizar(color!);
      if (_normalizar(p.colorPrimario) != c && _normalizar(p.colorSecundario) != c) return false;
    }
    final t = _normalizar(texto);
    if (t.isEmpty) return true;
    final campos = [p.nombre, p.categoria, p.colorPrimario, p.colorSecundario, p.tela, p.estilo, ...p.etiquetas];
    return campos.any((campo) => _normalizar(campo).contains(t));
  }

  List<Prenda> aplicar(List<Prenda> prendas) => prendas.where(acepta).toList();

  /// Colores que existen en el armario, para ofrecerlos como filtro.
  static List<String> coloresDe(List<Prenda> prendas) {
    final colores = <String>{
      for (final p in prendas) ...[p.colorPrimario, p.colorSecundario].where((c) => c.isNotEmpty),
    }.toList()
      ..sort();
    return colores;
  }
}
