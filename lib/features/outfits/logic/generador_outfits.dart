import '../../wardrobe/models/prenda.dart';
import '../models/outfit.dart';

/// Generador de outfits local (RF-03), sin internet ni IA: responde al instante
/// (RNF-01: sugerencia < 1 s) y no gasta cupos.
///
/// Reglas:
/// - Un outfit = superior + inferior (o un enterizo) + calzado si hay.
/// - Con frío o lluvia se agrega un abrigo si hay; en trabajo, fiesta o formal,
///   un accesorio si hay.
/// - Solo usa prendas de la formalidad adecuada para la ocasión y de la
///   estación adecuada para el clima. Si así no alcanza, relaja la formalidad.
/// - Puntúa la armonía de colores (neutros con todo; máximo 2 colores fuertes)
///   y prefiere prendas poco usadas (consumo responsable).
class GeneradorOutfits {
  const GeneradorOutfits();

  static const formalidadesPorOcasion = <String, List<String>>{
    'casual': ['casual', 'semiformal'],
    'universidad': ['casual', 'semiformal', 'deportivo'],
    'trabajo': ['semiformal', 'formal'],
    'deportivo': ['deportivo'],
    'fiesta': ['fiesta', 'semiformal', 'formal'],
    'formal': ['formal', 'semiformal'],
  };

  /// Colores que combinan con todo.
  static const neutros = {
    'negro', 'blanco', 'gris', 'gris oscuro', 'gris claro', 'beige', 'crema', 'café',
    'marrón', 'camel', 'caqui', 'azul', 'azul oscuro', 'azul marino', 'azul claro',
    'denim', 'hueso', 'nude',
  };

  static const _maxPorTipo = 8;

  List<Outfit> generar({
    required List<Prenda> prendas,
    required String ocasion,
    String clima = 'cualquiera',
    int cantidad = 3,
    Iterable<String> excluir = const {},
  }) {
    final estrictos = _combinaciones(prendas, ocasion, clima, relajarFormalidad: false);
    final todos = estrictos.length >= cantidad
        ? estrictos
        : [...estrictos, ..._combinaciones(prendas, ocasion, clima, relajarFormalidad: true)];

    final excluidos = excluir.toSet();
    final vistos = <String>{};
    final bases = <String>{};
    final elegidos = <_Combinacion>[];

    // Primera pasada: variedad (no repetir la misma base superior+inferior).
    // Segunda pasada: completar si no alcanzó.
    for (final variedad in [true, false]) {
      for (final c in todos) {
        if (elegidos.length >= cantidad) break;
        final clave = c.clave;
        if (excluidos.contains(clave) || vistos.contains(clave)) continue;
        if (variedad && bases.contains(c.base)) continue;
        vistos.add(clave);
        bases.add(c.base);
        elegidos.add(c);
      }
    }
    return elegidos.map((c) => _aOutfit(c, ocasion, clima)).toList();
  }

  bool _sirveParaClima(Prenda p, String clima) =>
      clima == 'cualquiera' || p.estacion == 'todo el año' || p.estacion == clima;

  List<_Combinacion> _combinaciones(
    List<Prenda> prendas,
    String ocasion,
    String clima, {
    required bool relajarFormalidad,
  }) {
    final formalidades = formalidadesPorOcasion[ocasion] ?? OpcionesPrenda.formalidades;
    final aptas = prendas.where((p) =>
        p.id != null &&
        _sirveParaClima(p, clima) &&
        (relajarFormalidad || formalidades.contains(p.formalidad)));

    List<Prenda> deTipo(String tipo) {
      final lista = aptas.where((p) => p.tipo == tipo).toList()
        ..sort((a, b) {
          final porUso = a.vecesUsada.compareTo(b.vecesUsada);
          return porUso != 0 ? porUso : a.id!.compareTo(b.id!);
        });
      return lista.take(_maxPorTipo).toList();
    }

    final superiores = deTipo('superior');
    final inferiores = deTipo('inferior');
    final enterizos = deTipo('enterizo');
    final calzados = deTipo('calzado');
    final abrigos = deTipo('abrigo');
    final accesorios = deTipo('accesorio');

    final bases = <List<Prenda>>[
      for (final s in superiores)
        for (final i in inferiores) [s, i],
      for (final e in enterizos) [e],
    ];

    final necesitaAbrigo = clima == 'frío' || clima == 'lluvia';
    final llevaAccesorio = const {'trabajo', 'fiesta', 'formal'}.contains(ocasion);

    final resultado = <_Combinacion>[];
    for (final base in bases) {
      final opcionesCalzado = calzados.isEmpty ? <Prenda?>[null] : calzados;
      for (final calzado in opcionesCalzado) {
        final piezas = [...base, ?calzado];
        if (necesitaAbrigo && abrigos.isNotEmpty) piezas.add(_mejorComplemento(piezas, abrigos));
        if (llevaAccesorio && accesorios.isNotEmpty) piezas.add(_mejorComplemento(piezas, accesorios));
        resultado.add(_Combinacion(
          piezas,
          base: base.map((p) => p.id).join('+'),
          puntaje: _puntaje(piezas, formalidades),
        ));
      }
    }
    resultado.sort((a, b) {
      final porPuntaje = b.puntaje.compareTo(a.puntaje);
      return porPuntaje != 0 ? porPuntaje : a.clave.compareTo(b.clave);
    });
    return resultado;
  }

  Prenda _mejorComplemento(List<Prenda> piezas, List<Prenda> opciones) {
    Prenda mejor = opciones.first;
    var mejorPuntaje = double.negativeInfinity;
    for (final o in opciones) {
      final p = _armonia([...piezas, o]) - o.vecesUsada * 0.01;
      if (p > mejorPuntaje) {
        mejorPuntaje = p;
        mejor = o;
      }
    }
    return mejor;
  }

  static String _color(Prenda p) => p.colorPrimario.trim().toLowerCase();

  /// Cuántos colores fuertes (no neutros) distintos hay en el outfit.
  static int coloresFuertes(List<Prenda> piezas) =>
      piezas.map(_color).where((c) => c.isNotEmpty && !neutros.contains(c)).toSet().length;

  double _armonia(List<Prenda> piezas) => switch (coloresFuertes(piezas)) {
        0 || 1 => 2,
        2 => 1,
        _ => -2,
      };

  double _puntaje(List<Prenda> piezas, List<String> formalidades) {
    var puntaje = _armonia(piezas);
    for (final p in piezas) {
      puntaje += 1 / (1 + p.vecesUsada); // consumo responsable
      if (formalidades.isNotEmpty && p.formalidad == formalidades.first) puntaje += 0.5;
    }
    return puntaje;
  }

  Outfit _aOutfit(_Combinacion c, String ocasion, String clima) {
    final fuertes = c.piezas.map(_color).where((x) => x.isNotEmpty && !neutros.contains(x)).toSet();
    final protagonista = fuertes.isNotEmpty
        ? fuertes.first
        : (c.piezas.map(_color).firstWhere((x) => x.isNotEmpty, orElse: () => ''));
    final nombre = [
      'Look ${OpcionesOutfit.etiquetaOcasion(ocasion).toLowerCase()}',
      if (protagonista.isNotEmpty) 'en $protagonista',
    ].join(' ');

    final nombres = c.piezas.map((p) => p.nombre.isEmpty ? p.categoria : p.nombre).toList();
    final lista = nombres.length == 1
        ? nombres.first
        : '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
    final colores = fuertes.isEmpty
        ? 'Los tonos neutros combinan entre sí sin esfuerzo.'
        : fuertes.length == 1
            ? 'El $protagonista resalta sobre una base neutra.'
            : 'Dos colores fuertes, equilibrados con el resto.';
    final poco = c.piezas.where((p) => p.vecesUsada == 0).length;
    final uso = poco > 0 ? ' Además le das uso a ${poco == 1 ? 'una prenda que' : 'prendas que'} aún no estrenas.' : '';

    return Outfit(
      nombre: nombre,
      prendaIds: c.piezas.map((p) => p.id!).toList(),
      ocasion: ocasion,
      clima: clima,
      explicacion: 'Combina $lista. $colores$uso',
      origen: 'local',
    );
  }
}

class _Combinacion {
  _Combinacion(this.piezas, {required this.base, required this.puntaje})
      : clave = (piezas.map((p) => p.id!).toList()..sort()).join('|');

  final List<Prenda> piezas;
  final String base;
  final double puntaje;
  final String clave;
}
