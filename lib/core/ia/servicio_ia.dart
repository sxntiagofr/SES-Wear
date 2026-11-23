import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/claves.dart';

/// Servicio de IA que usa la app: Gemini directo si hay `GEMINI_API_KEY` en
/// claves.json; si no, Firebase AI Logic.
ServicioIA get servicioIAPorDefecto =>
    Claves.hayGemini ? ServicioIAGemini.instancia : ServicioIAFirebase.instancia;

/// Un turno de la conversación que se le envía a la IA.
class TurnoIA {
  const TurnoIA({required this.delUsuario, required this.texto, this.imagen, this.tipoImagen = 'image/jpeg'});

  final bool delUsuario;
  final String texto;
  final Uint8List? imagen;
  final String tipoImagen;
}

/// Respuesta de texto de la IA. `bloqueada` si el filtro de seguridad la detuvo.
class RespuestaIA {
  const RespuestaIA({required this.texto, this.bloqueada = false});
  final String texto;
  final bool bloqueada;
}

/// Error de la IA con un mensaje listo para mostrar al usuario.
class ErrorIA implements Exception {
  const ErrorIA(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Acceso a Gemini. La app usa [ServicioIAFirebase]; las pruebas, uno falso.
abstract class ServicioIA {
  /// Conversación libre (asistente de moda).
  Future<RespuestaIA> conversar({required String instrucciones, required List<TurnoIA> historial});

  /// Respuesta en JSON con la forma de [esquema] (identificar prendas, outfits).
  Future<Map<String, dynamic>> generarJson({
    required String instrucciones,
    required TurnoIA pedido,
    required Schema esquema,
    double temperatura = 0.2,
  });
}

/// Gemini a través de Firebase AI Logic (proveedor Gemini Developer API).
///
/// No necesita API key en la app ni servidor propio: Firebase la gestiona.
/// Hay que activarlo una vez en Firebase Console → AI Logic → Comenzar
/// (ver docs/despliegue.md). Funciona en el plan gratuito Spark.
class ServicioIAFirebase implements ServicioIA {
  ServicioIAFirebase({List<String>? modelos}) : modelos = modelos ?? modelosPorDefecto;

  /// Modelos en orden de preferencia: si el primero está saturado o sin cupo,
  /// se intenta con el siguiente.
  static const modelosPorDefecto = ['gemini-flash-latest', 'gemini-flash-lite-latest'];

  final List<String> modelos;

  static final instancia = ServicioIAFirebase();

  static const _rechazo = 'Prefiero no responder eso. ¿Te ayudo con alguna idea de outfit o con algo de tu armario?';

  static Content _contenido(TurnoIA t) {
    final partes = <Part>[
      if (t.imagen != null) InlineDataPart(t.tipoImagen, t.imagen!),
      TextPart(t.texto),
    ];
    return t.delUsuario ? Content('user', partes) : Content('model', partes);
  }

  /// Ejecuta `llamada` con cada modelo hasta que uno responda.
  Future<T> _conRespaldo<T>(Future<T> Function(String modelo) llamada) async {
    Object? ultimo;
    for (final modelo in modelos) {
      try {
        return await llamada(modelo);
      } on ErrorIA {
        rethrow;
      } catch (e) {
        ultimo = e;
        if (!esErrorTemporal(e)) break;
        debugPrint('[IA] $modelo no disponible ($e); se intenta con el siguiente.');
      }
    }
    throw ErrorIA(mensajeDeError(ultimo));
  }

  @override
  Future<RespuestaIA> conversar({required String instrucciones, required List<TurnoIA> historial}) {
    return _conRespaldo((modelo) async {
      final ia = FirebaseAI.googleAI().generativeModel(
        model: modelo,
        systemInstruction: Content.system(instrucciones),
      );
      final respuesta = await ia.generateContent(historial.map(_contenido));
      try {
        final texto = respuesta.text?.trim() ?? '';
        if (texto.isEmpty) throw const ErrorIA('La IA no devolvió respuesta. Inténtalo de nuevo.');
        return RespuestaIA(texto: texto);
      } on FirebaseAIException catch (e) {
        // Respuesta bloqueada por los filtros de seguridad.
        if (e.message.contains('blocked')) return const RespuestaIA(texto: _rechazo, bloqueada: true);
        rethrow;
      }
    });
  }

  @override
  Future<Map<String, dynamic>> generarJson({
    required String instrucciones,
    required TurnoIA pedido,
    required Schema esquema,
    double temperatura = 0.2,
  }) {
    return _conRespaldo((modelo) async {
      final ia = FirebaseAI.googleAI().generativeModel(
        model: modelo,
        systemInstruction: Content.system(instrucciones),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: esquema,
          temperature: temperatura,
        ),
      );
      final respuesta = await ia.generateContent([_contenido(pedido)]);
      final texto = respuesta.text;
      if (texto == null || texto.trim().isEmpty) {
        throw const ErrorIA('La IA no pudo analizar la solicitud. Inténtalo de nuevo.');
      }
      final datos = jsonDecode(texto);
      if (datos is! Map<String, dynamic>) throw const ErrorIA('La IA respondió en un formato inesperado.');
      return datos;
    });
  }

  /// Saturación, cupo por minuto o error del servidor: vale la pena otro modelo.
  static bool esErrorTemporal(Object? e) =>
      !_apiSinActivar(e) && (e is QuotaExceeded || e is ServerException || e is FormatException);

  /// La API de Firebase AI Logic no está activada en el proyecto (a veces llega
  /// como ServerException con el texto del 403 SERVICE_DISABLED).
  static bool _apiSinActivar(Object? e) {
    if (e is ServiceApiNotEnabled) return true;
    final texto = e.toString();
    return texto.contains('SERVICE_DISABLED') ||
        texto.contains('has not been used in project') ||
        texto.contains('firebasevertexai.googleapis.com');
  }

  /// Mensaje en español para cada tipo de error de Firebase AI Logic.
  static String mensajeDeError(Object? e) {
    if (e is ErrorIA) return e.mensaje;
    if (_apiSinActivar(e)) {
      return 'La IA todavía no está activada: activa AI Logic en Firebase o pon GEMINI_API_KEY en claves.json.';
    }
    if (e is QuotaExceeded) {
      return 'Se acabó el cupo gratuito de la IA por ahora. Espera un momento e inténtalo de nuevo.';
    }
    if (e is InvalidApiKey) return 'La configuración de la IA en Firebase no es válida.';
    if (e is UnsupportedUserLocation) return 'La IA no está disponible en tu ubicación.';
    if (e is ServerException) return 'La IA no está disponible en este momento. Inténtalo de nuevo.';
    if (e is FormatException) return 'La IA respondió en un formato inesperado. Inténtalo de nuevo.';
    if (e is FirebaseAIException && e.message.contains('blocked')) {
      return 'La IA no pudo procesar esa solicitud. Prueba con otra foto o pregunta.';
    }
    return 'No se pudo conectar con la IA. Revisa tu conexión a internet.';
  }
}

/// Gemini llamado directamente con la API key de Google AI Studio
/// (`GEMINI_API_KEY` en claves.json). No necesita activar nada en Firebase.
///
/// La clave se crea gratis en https://aistudio.google.com/apikey.
class ServicioIAGemini implements ServicioIA {
  ServicioIAGemini({required this.clave, List<String>? modelos, http.Client? cliente})
      : modelos = modelos ?? ServicioIAFirebase.modelosPorDefecto,
        _cliente = cliente ?? http.Client();

  static final instancia = ServicioIAGemini(clave: Claves.gemini);

  static const _url = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const _tiempoMaximo = Duration(seconds: 60);
  static const _rechazo = ServicioIAFirebase._rechazo;

  final String clave;
  final List<String> modelos;
  final http.Client _cliente;

  static Map<String, Object> _contenido(TurnoIA t) => {
        'role': t.delUsuario ? 'user' : 'model',
        'parts': [
          if (t.imagen != null)
            {
              'inline_data': {'mime_type': t.tipoImagen, 'data': base64Encode(t.imagen!)},
            },
          {'text': t.texto},
        ],
      };

  /// Llama a `generateContent` con cada modelo hasta que uno responda.
  Future<Map<String, dynamic>> _generar(Map<String, Object> cuerpo) async {
    ErrorIA? ultimo;
    for (final modelo in modelos) {
      final http.Response r;
      try {
        r = await _cliente
            .post(
              Uri.parse('$_url/$modelo:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': clave},
              body: jsonEncode(cuerpo),
            )
            .timeout(_tiempoMaximo);
      } on TimeoutException {
        ultimo = const ErrorIA('La IA tardó demasiado en responder. Inténtalo de nuevo.');
        continue;
      } catch (_) {
        throw const ErrorIA('No se pudo conectar con la IA. Revisa tu conexión a internet.');
      }
      if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      debugPrint('[IA] $modelo respondió ${r.statusCode}: ${r.body}');
      ultimo = ErrorIA(_mensaje(r.statusCode, r.body));
      // Cupo o saturación: se prueba con el siguiente modelo.
      if (r.statusCode != 429 && r.statusCode < 500) break;
    }
    throw ultimo ?? const ErrorIA('La IA no está disponible en este momento.');
  }

  static String _mensaje(int estado, String cuerpo) {
    if (estado == 400 && cuerpo.contains('API_KEY_INVALID')) {
      return 'La clave de Gemini (GEMINI_API_KEY) no es válida. Revisa claves.json.';
    }
    if (estado == 400 && cuerpo.contains('location is not supported')) {
      return 'La IA no está disponible en tu ubicación.';
    }
    if (estado == 403) return 'La clave de Gemini no tiene permiso. Revisa claves.json.';
    if (estado == 429) return 'Se acabó el cupo gratuito de la IA por ahora. Espera un momento e inténtalo de nuevo.';
    if (estado >= 500) return 'La IA no está disponible en este momento. Inténtalo de nuevo.';
    return 'La IA no pudo procesar la solicitud ($estado).';
  }

  /// Texto de la primera respuesta, o null si el filtro de seguridad la bloqueó.
  static String? _texto(Map<String, dynamic> respuesta) {
    final candidatos = respuesta['candidates'];
    if (candidatos is! List || candidatos.isEmpty) return null;
    final partes = (candidatos.first as Map)['content']?['parts'];
    if (partes is! List) return null;
    return partes.map((p) => (p as Map)['text'] ?? '').join().trim();
  }

  @override
  Future<RespuestaIA> conversar({required String instrucciones, required List<TurnoIA> historial}) async {
    final respuesta = await _generar({
      'system_instruction': {
        'parts': [
          {'text': instrucciones},
        ],
      },
      'contents': historial.map(_contenido).toList(),
    });
    final texto = _texto(respuesta);
    if (texto == null) return const RespuestaIA(texto: _rechazo, bloqueada: true);
    if (texto.isEmpty) throw const ErrorIA('La IA no devolvió respuesta. Inténtalo de nuevo.');
    return RespuestaIA(texto: texto);
  }

  @override
  Future<Map<String, dynamic>> generarJson({
    required String instrucciones,
    required TurnoIA pedido,
    required Schema esquema,
    double temperatura = 0.2,
  }) async {
    final respuesta = await _generar({
      'system_instruction': {
        'parts': [
          {'text': instrucciones},
        ],
      },
      'contents': [_contenido(pedido)],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': esquema.toJson(),
        'temperature': temperatura,
      },
    });
    final texto = _texto(respuesta);
    if (texto == null || texto.isEmpty) {
      throw const ErrorIA('La IA no pudo analizar la solicitud. Inténtalo de nuevo.');
    }
    try {
      final datos = jsonDecode(texto);
      if (datos is Map<String, dynamic>) return datos;
    } on FormatException {
      // Se informa abajo.
    }
    throw const ErrorIA('La IA respondió en un formato inesperado. Inténtalo de nuevo.');
  }
}
