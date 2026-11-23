// IA con Firebase AI Logic (asistente, identificar prendas), cámara y login.
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ses_wear/core/ia/servicio_ia.dart';
import 'package:ses_wear/core/theme/app_theme.dart';
import 'package:ses_wear/features/assistant/data/asistente_repositorio.dart';
import 'package:ses_wear/features/assistant/logic/asistente_ia.dart';
import 'package:ses_wear/features/assistant/models/mensaje.dart';
import 'package:ses_wear/features/auth/models/perfil_usuario.dart';
import 'package:ses_wear/features/auth/screens/login_screen.dart';
import 'package:ses_wear/features/auth/screens/registro_screen.dart';
import 'package:ses_wear/features/wardrobe/data/prendas_repositorio.dart';
import 'package:ses_wear/features/wardrobe/logic/identificador_ia.dart';
import 'package:ses_wear/features/wardrobe/screens/camara_screen.dart';
import 'package:ses_wear/features/wardrobe/screens/nueva_prenda_screen.dart';

import '../auditoria/fakes.dart';
import 'repos_falsos.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Mensaje _u(String t) => Mensaje(rol: RolMensaje.usuario, texto: t);
Mensaje _a(String t) => Mensaje(rol: RolMensaje.asistente, texto: t);

void main() {
  group('Asistente (RF-04) con Firebase AI Logic', () {
    test('el historial empieza y termina con el usuario y se recorta', () {
      final turnos = AsistenteIA.prepararHistorial([
        _a('Hola, soy tu asistente'),
        _u('hola'),
        _a('¡Hola!'),
        _u('¿qué me pongo?'),
      ]);
      expect(turnos.map((t) => t.delUsuario), [true, false, true]);
      expect(turnos.last.texto, '¿qué me pongo?');

      final largo = [for (var i = 0; i < 60; i++) i.isEven ? _u('m$i') : _a('r$i'), _u('fin')];
      expect(AsistenteIA.prepararHistorial(largo).length, lessThanOrEqualTo(AsistenteIA.maxMensajes));
      expect(() => AsistenteIA.prepararHistorial([_u('hola'), _a('¡Hola!')]), throwsA(isA<ErrorIA>()));
    });

    test('el contexto incluye perfil y prendas sin mostrar ids como texto suelto', () {
      final ctx = AsistenteIA.contexto(
        const PerfilUsuario(
          uid: 'u',
          email: 'a@b.co',
          nombre: 'Ana',
          ciudad: 'Bogotá',
          preferencias: Preferencias(estilos: ['urbano']),
        ),
        armarioDePrueba,
      );
      expect(ctx, contains('Nombre del usuario: Ana.'));
      expect(ctx, contains('Ciudad: Bogotá.'));
      expect(ctx, contains('Estilos favoritos: urbano.'));
      expect(ctx, contains('ARMARIO DEL USUARIO (4 prendas'));
      expect(
        ctx,
        contains('- Jean azul (inferior, color azul, formalidad casual, para todo el año, usada 6 veces) [id: i1]'),
      );
      expect(AsistenteIA.contexto(null, const []), contains('todavía no ha registrado prendas'));
    });

    test('el repositorio envía el historial a la IA y devuelve la respuesta', () async {
      final ia = IAFalsa(texto: 'Ponte el **jean azul** con la camisa blanca.');
      final repo = AsistenteRepositorio(
        ia: ia,
        firestore: FakeFirestore(),
        auth: FakeAuth(currentUser: FakeUser()),
      );
      final r = await repo.enviar(historial: [_u('¿Qué me pongo para la U?')]);
      expect(r.texto, contains('jean azul'));
      expect(r.rechazado, isFalse);
      final pedido = ia.conversaciones.single;
      expect(pedido.instrucciones, startsWith('Eres el asistente de estilo de SES Wear'));
      expect(pedido.historial.single.texto, '¿Qué me pongo para la U?');
    });

    test('si la IA falla, el error llega con un mensaje para el usuario', () async {
      final repo = AsistenteRepositorio(
        ia: IAFalsa(error: const ErrorIA('Se acabó el cupo gratuito de la IA por ahora.')),
        firestore: FakeFirestore(),
        auth: FakeAuth(currentUser: FakeUser()),
      );
      await expectLater(
        repo.enviar(historial: [_u('hola')]),
        throwsA(isA<ErrorIA>().having((e) => e.mensaje, 'mensaje', contains('cupo'))),
      );
    });

    test('los errores de Firebase AI Logic se traducen al español', () {
      expect(
        ServicioIAFirebase.mensajeDeError(ServiceApiNotEnabled('projects/ses-wear')),
        contains('no está activada'),
      );
      expect(ServicioIAFirebase.mensajeDeError(QuotaExceeded('quota')), contains('cupo'));
      expect(ServicioIAFirebase.mensajeDeError(Exception('red')), contains('conexión'));
      expect(ServicioIAFirebase.esErrorTemporal(QuotaExceeded('q')), isTrue);
      expect(ServicioIAFirebase.esErrorTemporal(ServiceApiNotEnabled('p')), isFalse);
      // Así llega en web el 403 de un proyecto sin AI Logic activado.
      final desactivada = ServerException(
        'Firebase AI Logic API has not been used in project 123 before or it is disabled. SERVICE_DISABLED',
      );
      expect(ServicioIAFirebase.mensajeDeError(desactivada), contains('no está activada'));
      expect(ServicioIAFirebase.esErrorTemporal(desactivada), isFalse);
    });
  });

  group('Identificar prendas (RF-01) con Firebase AI Logic', () {
    test('envía la foto con el esquema y llena la prenda', () async {
      final ia = IAFalsa(
        json: {
          'esPrenda': true,
          'nombre': 'Jean azul clásico',
          'tipo': 'inferior',
          'categoria': 'JEAN',
          'colorPrimario': 'Azul',
          'tela': 'Denim',
          'estilo': 'clásico',
          'formalidad': 'casual',
          'estacion': 'todo el año',
          'etiquetas': ['a', 'b', 'c', 'd', 'e', 'f'],
        },
      );
      final repo = PrendasRepositorio(
        ia: ia,
        functions: FakeFunctions(),
        firestore: FakeFirestore(),
        storage: FakeStorage(),
        auth: FakeAuth(currentUser: FakeUser()),
      );
      final r = await repo.identificar(_png, tipo: 'image/png');
      expect(r.esPrenda, isTrue);
      expect(r.prenda.categoria, 'jean');
      expect(r.prenda.colorPrimario, 'azul');
      expect(r.prenda.etiquetas, hasLength(5));
      final pedido = ia.pedidosJson.single;
      expect(pedido.pedido.imagen, _png);
      expect(pedido.pedido.tipoImagen, 'image/png');
      expect(pedido.instrucciones, IdentificadorIA.instrucciones);
    });

    test('el esquema exige los campos principales y deja opcionales color secundario y etiquetas', () {
      final json = IdentificadorIA.esquema.toJson();
      expect((json['required'] as List), containsAll(['esPrenda', 'nombre', 'tipo', 'formalidad', 'estacion']));
      expect((json['required'] as List), isNot(contains('etiquetas')));
    });
  });

  group('Cámara (RF-01)', () {
    testWidgets('sin cámara ofrece elegir de la galería y abre el formulario', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CamaraScreen(
            repositorio: PrendasFalso(const []),
            buscarCamaras: () async => const [],
            elegirDeGaleria: () async => XFile.fromData(_png, mimeType: 'image/png', name: 'prenda.png'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No se encontró ninguna cámara'), findsOneWidget);
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      final formulario = tester.widget<NuevaPrendaScreen>(find.byType(NuevaPrendaScreen));
      expect(formulario.tipoImagen, 'image/png');
      expect(formulario.foto, _png);
    });

    testWidgets('si se niega el permiso, explica cómo darlo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CamaraScreen(
            repositorio: PrendasFalso(const []),
            buscarCamaras: () async => throw CameraException('CameraAccessDenied', 'denegado'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no tiene permiso para usar la cámara'), findsOneWidget);
      expect(find.text('Reintentar con la cámara'), findsOneWidget);
    });

    test('reconoce el tipo de imagen por el nombre del archivo', () {
      expect(tipoDeImagen(XFile.fromData(_png, path: 'a.PNG')), 'image/png');
      expect(tipoDeImagen(XFile.fromData(_png, path: 'a.heic')), 'image/heic');
      expect(tipoDeImagen(XFile.fromData(_png, path: 'a.jpg')), 'image/jpeg');
    });
  });

  group('Inicio de sesión sin Google ni Facebook', () {
    testWidgets('login y registro ya no muestran opciones sociales', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const LoginScreen()));
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(find.textContaining('continúa con'), findsNothing);
      expect(find.byTooltip('Continuar con Google'), findsNothing);
      expect(find.byIcon(Icons.facebook), findsNothing);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const RegistroScreen()));
      expect(find.textContaining('regístrate con'), findsNothing);
    });

    testWidgets('el logo del login es más pequeño', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const LoginScreen()));
      final logo = tester.getSize(find.byType(Image).first);
      expect(logo.height, lessThanOrEqualTo(150));
    });
  });
}
