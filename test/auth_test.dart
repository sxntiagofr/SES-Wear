import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/core/theme/app_theme.dart';
import 'package:ses_wear/features/auth/data/auth_repositorio.dart';
import 'package:ses_wear/features/auth/models/perfil_usuario.dart';
import 'package:ses_wear/features/auth/screens/login_screen.dart';
import 'package:ses_wear/features/auth/screens/registro_screen.dart';
import 'package:ses_wear/features/auth/widgets/auth_widgets.dart';

void main() {
  group('Validaciones del formulario', () {
    test('correo', () {
      expect(Validar.correo(''), isNotNull);
      expect(Validar.correo('ana@'), isNotNull);
      expect(Validar.correo('ana@correo'), isNotNull);
      expect(Validar.correo(' ana@correo.com '), isNull);
    });

    test('contraseña nueva: 8 caracteres con letras y números', () {
      expect(Validar.contrasenaNueva('abc123'), isNotNull);
      expect(Validar.contrasenaNueva('abcdefgh'), isNotNull);
      expect(Validar.contrasenaNueva('12345678'), isNotNull);
      expect(Validar.contrasenaNueva('moda2026'), isNull);
    });

    test('teléfono', () {
      expect(Validar.telefono(''), isNotNull);
      expect(Validar.telefono('12ab'), isNotNull);
      expect(Validar.telefono('300 123 4567'), isNull);
      expect(Validar.telefono('+57 300-123-4567'), isNull);
    });
  });

  group('PerfilUsuario', () {
    test('lee el documento de Firestore y protege el rol', () {
      final perfil = PerfilUsuario.desdeFirestore('u1', {
        'email': 'ana@correo.com',
        'nombre': 'Ana María',
        'apellido': 'Gómez',
        'rol': 'superadmin',
        'consentimientoDatos': {
          'aceptado': true,
          'fecha': Timestamp.fromDate(DateTime(2026, 11, 21)),
          'version': versionConsentimiento,
        },
      });
      expect(perfil.nombreCompleto, 'Ana María Gómez');
      expect(perfil.nombreCorto, 'Ana');
      expect(perfil.rol, 'usuario');
      expect(perfil.locale, 'es-CO');
      expect(perfil.consentimiento.vigente, isTrue);
    });

    test('sin autorización de datos no está vigente', () {
      final perfil = PerfilUsuario.desdeFirestore('u2', {'email': 'luis@correo.com'});
      expect(perfil.consentimiento.vigente, isFalse);
      expect(perfil.nombreCorto, 'luis');
    });

    test('un perfil nuevo siempre nace con rol usuario', () {
      const perfil = PerfilUsuario(uid: 'u3', email: 'x@y.co', rol: 'admin');
      final datos = perfil.aFirestoreNuevo();
      expect(datos['rol'], 'usuario');
      expect(datos.containsKey('consentimientoDatos'), isFalse);
    });
  });

  test('Los errores de Firebase se traducen a mensajes en español', () {
    expect(AuthRepositorio.mensajeDeError('invalid-credential'), contains('incorrectos'));
    expect(AuthRepositorio.mensajeDeError('email-already-in-use'), contains('Ya existe'));
    expect(AuthRepositorio.mensajeDeError('otro-codigo'), contains('otro-codigo'));
  });

  testWidgets('Iniciar sesión sin datos muestra qué falta', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const LoginScreen()));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
  });

  testWidgets('Registrarse exige la autorización de datos', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: const RegistroScreen()));
    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(find.text('Escribe tu nombre.'), findsOneWidget);
    expect(find.text('Debes aceptar la autorización para crear la cuenta.'), findsOneWidget);
  });
}
