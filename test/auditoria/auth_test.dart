// Auditoría del módulo de autenticación (RF-01: registro, inicio de sesión,
// recuperar contraseña) y de la puerta de entrada (AuthGate).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/core/services/sesion.dart';
import 'package:ses_wear/features/auth/data/auth_repositorio.dart';
import 'package:ses_wear/features/auth/models/perfil_usuario.dart';
import 'package:ses_wear/features/auth/screens/auth_gate.dart';

import 'fakes.dart';

void main() {
  group('AuthRepositorio.iniciarSesion', () {
    test('normaliza el correo y entra', () async {
      final auth = FakeAuth();
      final db = FakeFirestore();
      await AuthRepositorio(auth: auth, firestore: db)
          .iniciarSesion(email: '  Ana@Correo.COM ', contrasena: 'moda2026');
      expect(auth.ultimoCorreo, 'ana@correo.com');
      expect(db.docs['users/u1']?.containsKey('ultimoAcceso'), isTrue);
    });

    test('traduce credenciales inválidas a un mensaje en español', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(errorLogin: FirebaseAuthException(code: 'invalid-credential')),
        firestore: FakeFirestore(),
      );
      await expectLater(
        repo.iniciarSesion(email: 'a@b.co', contrasena: 'x'),
        throwsA(isA<ErrorAuth>().having((e) => e.mensaje, 'mensaje', contains('incorrectos'))),
      );
    });

    test('si falla guardar el último acceso igual deja entrar', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(),
        firestore: FakeFirestore(errorAlEscribir: FirebaseException(plugin: 'firestore', code: 'unavailable')),
      );
      await repo.iniciarSesion(email: 'a@b.co', contrasena: 'moda2026');
    });
  });

  group('AuthRepositorio.registrar', () {
    Future<void> registrar(AuthRepositorio repo, {bool acepta = true}) => repo.registrar(
          nombre: ' Ana ',
          apellido: 'Gómez ',
          telefono: '3001234567',
          email: 'Ana@Correo.com',
          contrasena: 'moda2026',
          aceptaDatos: acepta,
        );

    test('sin aceptar la autorización de datos no crea la cuenta', () async {
      final auth = FakeAuth();
      await expectLater(registrar(AuthRepositorio(auth: auth, firestore: FakeFirestore()), acepta: false),
          throwsA(isA<ErrorAuth>()));
      expect(auth.creoCuenta, isFalse);
    });

    test('crea el perfil users/{uid} con consentimiento y nombre', () async {
      final auth = FakeAuth();
      final db = FakeFirestore();
      await registrar(AuthRepositorio(auth: auth, firestore: db));
      final doc = db.docs['users/u1']!;
      expect(doc['nombre'], 'Ana');
      expect(doc['apellido'], 'Gómez');
      expect(doc['email'], 'ana@correo.com');
      expect(doc['rol'], 'usuario');
      expect((doc['consentimientoDatos'] as Map)['aceptado'], isTrue);
      expect(auth.nuevo.displayName, 'Ana Gómez');
    });

    test('correo ya registrado → mensaje claro', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(errorRegistro: FirebaseAuthException(code: 'email-already-in-use')),
        firestore: FakeFirestore(),
      );
      await expectLater(registrar(repo),
          throwsA(isA<ErrorAuth>().having((e) => e.mensaje, 'mensaje', contains('Ya existe'))));
    });

    test('si Firestore falla al guardar el perfil, borra la cuenta para reintentar', () async {
      final auth = FakeAuth();
      final repo = AuthRepositorio(
        auth: auth,
        firestore: FakeFirestore(errorAlEscribir: FirebaseException(plugin: 'firestore', code: 'permission-denied')),
      );
      await expectLater(registrar(repo), throwsA(isA<ErrorAuth>()));
      expect(auth.nuevo.borrado, isTrue);
    });

    test('Regresión: si solo falla updateDisplayName, NO debería borrar la cuenta (el perfil ya se guardó)', () async {
      final usuario = FakeUser(errorAlActualizarNombre: FirebaseAuthException(code: 'network-request-failed'));
      final auth = FakeAuth(nuevo: usuario);
      final db = FakeFirestore();
      try {
        await registrar(AuthRepositorio(auth: auth, firestore: db));
      } catch (_) {}
      // Hoy: la cuenta se borra pero el documento users/u1 (con datos personales) queda huérfano.
      expect(db.docs.containsKey('users/u1'), isTrue, reason: 'el perfil se guardó');
      expect(usuario.borrado, isFalse,
          reason: 'la cuenta se borró aunque el perfil sí se guardó → documento huérfano en Firestore');
    });
  });

  group('AuthRepositorio.recuperarContrasena', () {
    test('no revela si el correo existe (user-not-found es silencioso)', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(errorReset: FirebaseAuthException(code: 'user-not-found')),
        firestore: FakeFirestore(),
      );
      await repo.recuperarContrasena('nadie@correo.com');
    });

    test('correo inválido → ErrorAuth', () async {
      final repo = AuthRepositorio(
        auth: FakeAuth(errorReset: FirebaseAuthException(code: 'invalid-email')),
        firestore: FakeFirestore(),
      );
      await expectLater(repo.recuperarContrasena('x'), throwsA(isA<ErrorAuth>()));
    });
  });

  group('Sesion.uid', () {
    test('sin usuario lanza error', () {
      expect(Sesion.uid(FakeAuth()), throwsA(isA<FirebaseAuthException>()));
    });
    test('usuario anónimo no cuenta como sesión', () {
      expect(Sesion.uid(FakeAuth(currentUser: FakeUser(isAnonymous: true))),
          throwsA(isA<FirebaseAuthException>()));
    });
    test('usuario con cuenta devuelve su uid', () async {
      expect(await Sesion.uid(FakeAuth(currentUser: FakeUser(uid: 'abc'))), 'abc');
    });
  });

  group('AuthGate', () {
    Widget gate(AuthRepositorio repo) =>
        MaterialApp(home: AuthGate(repositorio: repo, app: const Text('APP')));

    testWidgets('sin sesión muestra Iniciar sesión', (tester) async {
      await tester.pumpWidget(gate(AuthRepositorio(auth: FakeAuth(), firestore: FakeFirestore())));
      await tester.pump();
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(find.text('APP'), findsNothing);
    });

    testWidgets('con sesión y autorización vigente muestra la app', (tester) async {
      final db = FakeFirestore()
        ..docs['users/u1'] = {
          'email': 'ana@correo.com',
          'consentimientoDatos': {'aceptado': true, 'version': versionConsentimiento},
        };
      await tester.pumpWidget(gate(AuthRepositorio(auth: FakeAuth(currentUser: FakeUser()), firestore: db)));
      await tester.pump();
      await tester.pump();
      expect(find.text('APP'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9)); // deja vencer el temporizador de _Cargando
    });

    testWidgets('con sesión sin autorización pide aceptarla', (tester) async {
      final db = FakeFirestore()..docs['users/u1'] = {'email': 'ana@correo.com'};
      await tester.pumpWidget(gate(AuthRepositorio(auth: FakeAuth(currentUser: FakeUser()), firestore: db)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Acepto y continuar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('con sesión pero sin perfil ofrece reintentar o cerrar sesión', (tester) async {
      await tester.pumpWidget(
          gate(AuthRepositorio(auth: FakeAuth(currentUser: FakeUser()), firestore: FakeFirestore())));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('APP'), findsNothing);
    });
  });
}
