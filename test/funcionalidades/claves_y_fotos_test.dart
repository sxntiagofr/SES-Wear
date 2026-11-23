import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:ses_wear/core/ia/servicio_ia.dart';
import 'package:ses_wear/core/utils/imagenes.dart';

void main() {
  group('Fotos guardadas en Firestore', () {
    test('una foto grande se reduce y cabe en un documento', () {
      final grande = img.Image(width: 2000, height: 1500);
      img.fill(grande, color: img.ColorRgb8(30, 90, 200));
      final jpg = img.encodeJpg(grande);
      final r = comprimirFoto(jpg, tipo: 'image/jpeg');
      expect(r.tipo, 'image/jpeg');
      final reducida = img.decodeImage(r.bytes)!;
      expect(reducida.width, 640);
      expect(r.comoDataUrl.length, lessThan(900000));
      expect(r.comoDataUrl, startsWith('data:image/jpeg;base64,'));
    });

    test('una foto sin fondo (PNG transparente) sigue siendo PNG', () {
      final png = img.encodePng(img.Image(width: 300, height: 300, numChannels: 4));
      final r = comprimirFoto(png, tipo: 'image/png');
      expect(r.tipo, 'image/png');
    });

    test('las fotos data: se muestran desde memoria y las https desde la red', () {
      final url = 'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 2, height: 2)))}';
      expect(imagenDesdeUrl(url), isA<MemoryImage>());
      expect(identical(imagenDesdeUrl(url), imagenDesdeUrl(url)), isTrue);
      expect(imagenDesdeUrl('https://ejemplo.com/a.png'), isA<NetworkImage>());
    });
  });

  group('Gemini con API key (claves.json)', () {
    Map<String, dynamic> respuesta(String texto) => {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': texto},
                ],
              },
            },
          ],
        };

    test('el asistente responde y envía instrucciones e historial', () async {
      late Map<String, dynamic> enviado;
      final ia = ServicioIAGemini(
        clave: 'clave-prueba',
        cliente: MockClient((pedido) async {
          expect(pedido.headers['x-goog-api-key'], 'clave-prueba');
          enviado = jsonDecode(pedido.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(respuesta('Ponte el jean azul.')), 200);
        }),
      );
      final r = await ia.conversar(
        instrucciones: 'Eres asistente de moda',
        historial: const [TurnoIA(delUsuario: true, texto: '¿Qué me pongo?')],
      );
      expect(r.texto, 'Ponte el jean azul.');
      expect((enviado['contents'] as List).single['role'], 'user');
      expect(enviado['system_instruction'], isNotNull);
    });

    test('pide JSON con el esquema y lo devuelve', () async {
      final ia = ServicioIAGemini(
        clave: 'k',
        cliente: MockClient((pedido) async {
          final cuerpo = jsonDecode(pedido.body) as Map<String, dynamic>;
          expect(cuerpo['generationConfig']['responseMimeType'], 'application/json');
          return http.Response(jsonEncode(respuesta('{"esPrenda": true, "nombre": "Jean"}')), 200);
        }),
      );
      final datos = await ia.generarJson(
        instrucciones: 'x',
        pedido: const TurnoIA(delUsuario: true, texto: 'Identifica'),
        esquema: Schema.object(properties: {'esPrenda': Schema.boolean(), 'nombre': Schema.string()}),
      );
      expect(datos['nombre'], 'Jean');
    });

    test('si se acaba el cupo prueba el siguiente modelo', () async {
      final modelos = <String>[];
      final ia = ServicioIAGemini(
        clave: 'k',
        modelos: const ['a', 'b'],
        cliente: MockClient((pedido) async {
          modelos.add(pedido.url.pathSegments.last);
          return modelos.length == 1
              ? http.Response('{"error":{}}', 429)
              : http.Response(jsonEncode(respuesta('ok')), 200);
        }),
      );
      final r = await ia.conversar(instrucciones: 'x', historial: const [TurnoIA(delUsuario: true, texto: 'hola')]);
      expect(r.texto, 'ok');
      expect(modelos, ['a:generateContent', 'b:generateContent']);
    });

    test('una clave inválida da un mensaje claro', () async {
      final ia = ServicioIAGemini(
        clave: 'mala',
        cliente: MockClient((_) async => http.Response('{"error":{"status":"API_KEY_INVALID"}}', 400)),
      );
      expect(
        () => ia.conversar(instrucciones: 'x', historial: const [TurnoIA(delUsuario: true, texto: 'hola')]),
        throwsA(isA<ErrorIA>().having((e) => e.mensaje, 'mensaje', contains('GEMINI_API_KEY'))),
      );
    });
  });
}
