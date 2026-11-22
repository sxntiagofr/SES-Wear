import 'package:firebase_ai/firebase_ai.dart';

import '../models/prenda.dart';

/// Identificación automática de prendas con Gemini (RF-01): instrucciones y
/// forma de la respuesta. Versión en Dart de `functions/src/identificador.js`.
class IdentificadorIA {
  IdentificadorIA._();

  static const instrucciones = '''Eres el módulo de reconocimiento de prendas de SES Wear, una app de armario digital en Colombia.
Recibes la foto de UNA prenda de ropa, calzado o accesorio y devuelves sus atributos para registrarla en el armario del usuario.

Reglas:
- Responde en español de Colombia con el léxico local: saco, buso, chaqueta, jean, tenis, chanclas, camiseta, blusa, pantaloneta, sudadera, camisa, vestido, falda.
- "nombre": nombre corto y descriptivo, p. ej. "Jean azul clásico" o "Buso gris con capota".
- "categoria": la prenda concreta en minúscula, p. ej. "jean", "camiseta", "tenis", "buso", "vestido".
- Colores en minúscula y simples (negro, blanco, gris, azul oscuro, beige, rojo...). "colorSecundario" vacío si la prenda es de un solo color.
- "tela": la tela o textura que se ve (denim, algodón, lana, cuero, poliéster, lino, seda, punto...). Si no se distingue, la más probable.
- "estilo": una o dos palabras (clásico, urbano, deportivo, elegante, bohemio, minimalista...).
- "etiquetas": de 2 a 5 palabras útiles para buscar la prenda (estampado, manga larga, oversize, rasgado...).
- Si en la foto hay varias prendas, describe la más visible o la que está en el centro.
- Si la foto no muestra ropa, calzado ni accesorios, pon "esPrenda": false y deja los demás campos vacíos.
- Describe solo la prenda, nunca a la persona que la lleva puesta.''';

  static final esquema = Schema.object(
    properties: {
      'esPrenda': Schema.boolean(),
      'nombre': Schema.string(),
      'tipo': Schema.enumString(enumValues: OpcionesPrenda.tipos),
      'categoria': Schema.string(),
      'colorPrimario': Schema.string(),
      'colorSecundario': Schema.string(),
      'tela': Schema.string(),
      'estilo': Schema.string(),
      'formalidad': Schema.enumString(enumValues: OpcionesPrenda.formalidades),
      'estacion': Schema.enumString(enumValues: OpcionesPrenda.estaciones),
      'etiquetas': Schema.array(items: Schema.string()),
    },
    optionalProperties: ['colorSecundario', 'etiquetas'],
    propertyOrdering: [
      'esPrenda', 'nombre', 'tipo', 'categoria', 'colorPrimario', 'colorSecundario',
      'tela', 'estilo', 'formalidad', 'estacion', 'etiquetas',
    ],
  );

  /// Pone en minúscula los campos de texto libre y limita las etiquetas.
  static Map<String, dynamic> normalizar(Map<String, dynamic> datos) {
    String minuscula(String campo) => (datos[campo] is String ? datos[campo] as String : '').trim().toLowerCase();
    final etiquetas = datos['etiquetas'] is List ? (datos['etiquetas'] as List).whereType<String>().take(5).toList() : <String>[];
    return {
      ...datos,
      for (final campo in ['categoria', 'colorPrimario', 'colorSecundario', 'tela', 'estilo']) campo: minuscula(campo),
      'etiquetas': etiquetas,
    };
  }
}
