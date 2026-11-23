import '../../../core/ia/servicio_ia.dart';
import '../../auth/models/perfil_usuario.dart';
import '../../wardrobe/models/prenda.dart';
import '../models/mensaje.dart';

/// Lógica del asistente de moda (RF-04), sin dependencias de Firebase:
/// instrucciones para Gemini, contexto del usuario y preparación del historial.
/// Versión en Dart de `functions/src/asistente.js` y `functions/src/datos.js`.
class AsistenteIA {
  AsistenteIA._();

  static const maxMensajes = 40;
  static const maxCaracteres = 4000;
  static const maxPrendasEnContexto = 150;

  static const instrucciones = '''Eres el asistente de estilo de SES Wear, una app móvil que funciona como clóset digital inteligente. El eslogan de la app es "Tu estilo, más inteligente".

Tu trabajo es conversar con el usuario sobre su ropa y su forma de vestir: ideas de combinaciones, qué ponerse según la ocasión (casual, trabajo, universidad, deportivo, fiesta, entrevista) y el clima, colores que combinan, tendencias, y cómo proyectar la imagen que el usuario quiere. También puedes tener una conversación normal y amable si el usuario simplemente quiere charlar.

Forma de hablar:
- Español de Colombia, cercano y natural, tuteando al usuario.
- Usa el léxico colombiano de prendas: saco, buso, chaqueta, jean, tenis, chanclas, camiseta, blusa, pantaloneta, sudadera.
- Respuestas cortas y concretas, como en un chat del celular: normalmente entre 2 y 6 frases. Si das varias opciones, usa una lista corta con guiones.
- No uses títulos ni tablas. Puedes resaltar una palabra clave con **negrita**.
- Empieza a responder de inmediato, sin preámbulos.

Criterio:
- No impongas una única forma de vestir: adapta las sugerencias a los gustos del usuario y a lo que te cuente que tiene en su armario.
- Promueve el consumo responsable: antes de sugerir comprar algo, propone combinaciones con prendas que el usuario ya tiene.
- Si te falta información importante (ocasión, clima, estilo), haz una sola pregunta corta.
- Si al final de estas instrucciones aparece el ARMARIO DEL USUARIO (las prendas que guardó en la app), úsalo: recomienda combinaciones con esas prendas, nómbralas como aparecen y no inventes prendas que no estén en la lista. Nunca muestres los [id: ...] de las prendas.
- Si el armario está vacío o no aparece, dile que puede registrar sus prendas con el botón de la cámara y pídele que te cuente qué tiene.
- Opina solo sobre la ropa, nunca sobre el cuerpo o el físico de la persona.''';

  static String _color(Prenda p) =>
      [p.colorPrimario, p.colorSecundario].where((c) => c.isNotEmpty).join(' y ');

  /// Una línea corta y legible por prenda.
  static String describirPrenda(Prenda p) {
    final nombre = p.nombre.isNotEmpty ? p.nombre : (p.categoria.isNotEmpty ? p.categoria : 'Prenda sin nombre');
    final detalles = [
      p.tipo,
      if (p.categoria.isNotEmpty && p.categoria != nombre) p.categoria,
      if (_color(p).isNotEmpty) 'color ${_color(p)}',
      if (p.tela.isNotEmpty) 'tela ${p.tela}',
      'formalidad ${p.formalidad}',
      'para ${p.estacion}',
      'usada ${p.vecesUsada} ${p.vecesUsada == 1 ? 'vez' : 'veces'}',
      if (p.etiquetas.isNotEmpty) 'etiquetas: ${p.etiquetas.take(5).join(', ')}',
    ];
    return '- $nombre (${detalles.join(', ')}) [id: ${p.id}]';
  }

  /// Bloque con el perfil y el armario del usuario.
  static String contexto(PerfilUsuario? perfil, List<Prenda> prendas) {
    final lineas = <String>[];
    if (perfil != null) {
      if (perfil.nombre.isNotEmpty) lineas.add('Nombre del usuario: ${perfil.nombre}.');
      if (perfil.ciudad.isNotEmpty) lineas.add('Ciudad: ${perfil.ciudad}.');
      final p = perfil.preferencias;
      if (p.estilos.isNotEmpty) lineas.add('Estilos favoritos: ${p.estilos.join(', ')}.');
      if (p.colores.isNotEmpty) lineas.add('Colores favoritos: ${p.colores.join(', ')}.');
      if (p.ocasiones.isNotEmpty) lineas.add('Ocasiones frecuentes: ${p.ocasiones.join(', ')}.');
    }
    if (prendas.isEmpty) {
      lineas.add('ARMARIO: el usuario todavía no ha registrado prendas en la app.');
    } else {
      final lista = prendas.take(maxPrendasEnContexto).toList();
      lineas.add('ARMARIO DEL USUARIO (${prendas.length} prendas guardadas en la app):');
      lineas.addAll(lista.map(describirPrenda));
      if (prendas.length > maxPrendasEnContexto) {
        lineas.add('(Se muestran solo las primeras $maxPrendasEnContexto prendas.)');
      }
    }
    return lineas.join('\n');
  }

  static String instruccionesCon(String contexto) =>
      '$instrucciones\n\n--- Datos del usuario (desde la base de datos de la app) ---\n$contexto';

  /// Últimos mensajes, empezando por uno del usuario y terminando en uno del
  /// usuario, sin mensajes vacíos y con un largo máximo.
  static List<TurnoIA> prepararHistorial(List<Mensaje> mensajes) {
    final recientes = mensajes
        .where((m) => m.texto.trim().isNotEmpty)
        .toList()
        .reversed
        .take(maxMensajes)
        .toList()
        .reversed
        .toList();
    while (recientes.isNotEmpty && !recientes.first.esDelUsuario) {
      recientes.removeAt(0);
    }
    if (recientes.isEmpty || !recientes.last.esDelUsuario) {
      throw const ErrorIA('Escribe tu pregunta para el asistente.');
    }
    return [
      for (final m in recientes)
        TurnoIA(
          delUsuario: m.esDelUsuario,
          texto: m.texto.length > maxCaracteres ? m.texto.substring(0, maxCaracteres) : m.texto.trim(),
        ),
    ];
  }
}
