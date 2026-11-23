import 'package:firebase_ai/firebase_ai.dart';

import '../../wardrobe/models/prenda.dart';
import '../models/outfit.dart';

/// Generador de outfits con Gemini (RF-03): instrucciones, pedido y
/// validación de la respuesta. Versión en Dart de `functions/src/outfits.js`.
class OutfitsIA {
  OutfitsIA._();

  static const maxPrendas = 150;
  static const maxExcluidos = 30;

  static const instrucciones = '''Eres el generador de outfits de SES Wear, una app de armario digital en Colombia.
Recibes la lista de prendas del usuario (cada una con su id) y armas combinaciones completas para la ocasión y el clima pedidos.

Reglas:
- Usa SOLO prendas de la lista, referenciadas por su id exacto. Nunca inventes prendas ni ids.
- Un outfit completo lleva: una prenda superior y una inferior (o un enterizo), y calzado si hay. Agrega abrigo si el clima es frío o lluvia y hay uno. Un accesorio es opcional.
- Respeta la formalidad de la ocasión y combina colores con criterio (neutros con todo; máximo dos colores fuertes).
- Promueve el consumo responsable: prefiere prendas poco usadas cuando combinen bien.
- No repitas ninguna de las combinaciones que aparecen como "ya mostradas".
- "nombre": 2 a 5 palabras, p. ej. "Urbano relajado para la U".
- "explicacion": una o dos frases en español de Colombia, tuteando, diciendo por qué funciona.
- Si no hay prendas suficientes para un outfit completo, devuelve la lista vacía.''';

  static final esquema = Schema.object(
    properties: {
      'outfits': Schema.array(
        items: Schema.object(
          properties: {
            'nombre': Schema.string(),
            'prendaIds': Schema.array(items: Schema.string()),
            'explicacion': Schema.string(),
          },
          propertyOrdering: ['nombre', 'prendaIds', 'explicacion'],
        ),
      ),
    },
  );

  /// Una línea por prenda, con su id, para el pedido.
  static String describirPrendas(List<Prenda> prendas) => prendas.take(maxPrendas).map((p) {
        final colores = [p.colorPrimario, p.colorSecundario].where((c) => c.isNotEmpty).join(' y ');
        final datos = [p.tipo, p.categoria, colores, p.formalidad, p.estacion, 'usada ${p.vecesUsada}']
            .where((d) => d.isNotEmpty)
            .join(', ');
        final nombre = p.nombre.isNotEmpty ? p.nombre : (p.categoria.isNotEmpty ? p.categoria : 'prenda');
        return '- id ${p.id}: $nombre ($datos)';
      }).join('\n');

  static String pedido({
    required List<Prenda> prendas,
    required String ocasion,
    required String clima,
    required int cantidad,
    List<List<String>> excluir = const [],
  }) {
    final recientes = excluir.length > maxExcluidos ? excluir.sublist(excluir.length - maxExcluidos) : excluir;
    final yaMostradas = recientes.isEmpty
        ? ''
        : '\n\nCombinaciones ya mostradas (no las repitas):\n${recientes.map((ids) => '- ${ids.join(', ')}').join('\n')}';
    return 'Ocasión: $ocasion. Clima: $clima. Arma $cantidad outfits distintos.\n\n'
        'Prendas del usuario:\n${describirPrendas(prendas)}$yaMostradas';
  }

  static String _clave(Iterable<String> ids) => (ids.toList()..sort()).join('|');

  /// Deja solo outfits válidos: ids que existen, sin repetir, con al menos 2
  /// prendas y que no estén entre los ya mostrados.
  static List<Outfit> normalizar(
    Map<String, dynamic> datos, {
    required Set<String> idsValidos,
    required String ocasion,
    required String clima,
    List<List<String>> excluir = const [],
    int cantidad = 3,
  }) {
    final vistos = excluir.map(_clave).toSet();
    final resultado = <Outfit>[];
    final lista = datos['outfits'] is List ? datos['outfits'] as List : const [];
    for (final o in lista.whereType<Map>()) {
      final ids = <String>{
        for (final id in (o['prendaIds'] is List ? o['prendaIds'] as List : const []))
          if (id is String && idsValidos.contains(id)) id,
      }.toList();
      if (ids.length < 2 || vistos.contains(_clave(ids))) continue;
      vistos.add(_clave(ids));
      final nombre = o['nombre'] is String ? (o['nombre'] as String).trim() : '';
      resultado.add(Outfit(
        nombre: nombre.isEmpty ? 'Outfit sugerido' : nombre,
        prendaIds: ids,
        explicacion: o['explicacion'] is String ? (o['explicacion'] as String).trim() : '',
        ocasion: ocasion,
        clima: clima,
        origen: 'ia',
      ));
      if (resultado.length >= cantidad) break;
    }
    return resultado;
  }
}
