import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/auth_config.dart';
import '../models/perfil_usuario.dart';

/// Error de inicio de sesión con un mensaje listo para mostrar al usuario.
class ErrorAuth implements Exception {
  const ErrorAuth(this.mensaje, {this.codigo});

  final String mensaje;
  final String? codigo;

  @override
  String toString() => mensaje;
}

/// El usuario cerró la ventana de Google o Facebook sin elegir cuenta.
class InicioCancelado implements Exception {
  const InicioCancelado();
}

/// Cuentas de usuario (Firebase Authentication) y su perfil (Cloud Firestore).
///
/// - Correo y contraseña: registro, inicio de sesión y recuperación por correo.
/// - Google y Facebook: inicio de sesión social; la primera vez se crea el perfil.
/// - Cada cuenta tiene su documento `users/{uid}` con los datos del registro.
class AuthRepositorio {
  AuthRepositorio({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static final AuthRepositorio instancia = AuthRepositorio();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static Future<void>? _googleListo;

  DocumentReference<Map<String, dynamic>> _perfilRef(String uid) =>
      _firestore.collection('users').doc(uid);

  User? get usuarioActual => _auth.currentUser;

  /// Emite el usuario cuando inicia o cierra sesión. La sesión se guarda en el
  /// celular: si ya había entrado antes, la app abre directo en Inicio.
  Stream<User?> cambiosDeSesion() => _auth.authStateChanges();

  /// Perfil del usuario en tiempo real (null si el documento aún no existe).
  Stream<PerfilUsuario?> observarPerfil(String uid) {
    return _perfilRef(uid).snapshots().map((doc) {
      final datos = doc.data();
      return datos == null ? null : PerfilUsuario.desdeFirestore(uid, datos);
    });
  }

  // ---------------------------------------------------------------------------
  // Correo y contraseña
  // ---------------------------------------------------------------------------

  Future<void> iniciarSesion({required String email, required String contrasena}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: contrasena,
      );
      await _registrarAcceso(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw ErrorAuth(mensajeDeError(e.code), codigo: e.code);
    }
  }

  /// Crea la cuenta en Firebase Authentication y el documento `users/{uid}`.
  Future<void> registrar({
    required String nombre,
    required String apellido,
    required String telefono,
    required String email,
    required String contrasena,
    required bool aceptaDatos,
  }) async {
    if (!aceptaDatos) {
      throw const ErrorAuth('Debes aceptar la autorización de tratamiento de datos para crear la cuenta.');
    }
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: contrasena,
      );
    } on FirebaseAuthException catch (e) {
      throw ErrorAuth(mensajeDeError(e.code), codigo: e.code);
    }

    final usuario = cred.user!;
    final perfil = PerfilUsuario(
      uid: usuario.uid,
      email: usuario.email ?? email.trim().toLowerCase(),
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      telefono: telefono.trim(),
      proveedor: 'password',
      consentimiento: const ConsentimientoDatos(aceptado: true),
    );

    try {
      await _perfilRef(usuario.uid).set(perfil.aFirestoreNuevo());
      await usuario.updateDisplayName(perfil.nombreCompleto);
    } on FirebaseException catch (e) {
      // La cuenta quedó creada pero sin perfil: se borra para que pueda
      // registrarse de nuevo con el mismo correo.
      await usuario.delete().catchError((_) {});
      throw ErrorAuth(
        'No se pudieron guardar tus datos (${e.code}). Revisa tu conexión e inténtalo de nuevo.',
        codigo: e.code,
      );
    }
  }

  /// Envía el correo de Firebase para crear una contraseña nueva.
  Future<void> recuperarContrasena(String email) async {
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      // Por seguridad no se revela si el correo existe o no.
      if (e.code == 'user-not-found') return;
      throw ErrorAuth(mensajeDeError(e.code), codigo: e.code);
    }
  }

  // ---------------------------------------------------------------------------
  // Google y Facebook
  // ---------------------------------------------------------------------------

  Future<void> iniciarConGoogle() async {
    try {
      final UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final google = GoogleSignIn.instance;
        _googleListo ??= google.initialize(
          serverClientId: AuthConfig.googleServerClientId.isEmpty
              ? null
              : AuthConfig.googleServerClientId,
        );
        await _googleListo;
        final cuenta = await google.authenticate();
        final idToken = cuenta.authentication.idToken;
        if (idToken == null) {
          throw const ErrorAuth('Google no devolvió los datos de la cuenta. Inténtalo de nuevo.');
        }
        cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      await _asegurarPerfil(cred, proveedor: 'google.com');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const InicioCancelado();
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const ErrorAuth(
          'El inicio con Google aún no está configurado en Firebase. Revisa docs/autenticacion.md.',
        );
      }
      throw ErrorAuth('No se pudo iniciar sesión con Google (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      if (_esCancelacion(e.code)) throw const InicioCancelado();
      throw ErrorAuth(mensajeDeError(e.code), codigo: e.code);
    }
  }

  Future<void> iniciarConFacebook() async {
    if (!kIsWeb && !AuthConfig.facebookConfigurado) {
      throw const ErrorAuth(
        'El inicio con Facebook está listo en el código, pero falta poner las claves de la app de Meta. Revisa docs/autenticacion.md.',
      );
    }
    try {
      final UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(FacebookAuthProvider()..addScope('email'));
      } else {
        final resultado = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
        switch (resultado.status) {
          case LoginStatus.success:
            final token = resultado.accessToken!.tokenString;
            cred = await _auth.signInWithCredential(FacebookAuthProvider.credential(token));
          case LoginStatus.cancelled:
            throw const InicioCancelado();
          case LoginStatus.failed:
          case LoginStatus.operationInProgress:
            throw ErrorAuth('No se pudo iniciar sesión con Facebook. ${resultado.message ?? ''}'.trim());
        }
      }
      await _asegurarPerfil(cred, proveedor: 'facebook.com');
    } on FirebaseAuthException catch (e) {
      if (_esCancelacion(e.code)) throw const InicioCancelado();
      throw ErrorAuth(mensajeDeError(e.code), codigo: e.code);
    }
  }

  // ---------------------------------------------------------------------------
  // Perfil y sesión
  // ---------------------------------------------------------------------------

  /// Guarda la autorización de tratamiento de datos (la piden las cuentas de
  /// Google o Facebook la primera vez que entran).
  Future<void> aceptarConsentimiento(String uid) {
    return _perfilRef(uid).set(
      {'consentimientoDatos': const ConsentimientoDatos(aceptado: true).aFirestore()},
      SetOptions(merge: true),
    );
  }

  /// Crea el documento `users/{uid}` si es la primera vez que entra con Google
  /// o Facebook; si ya existe, solo actualiza la fecha del último acceso.
  Future<void> _asegurarPerfil(UserCredential cred, {required String proveedor}) async {
    final usuario = cred.user!;
    final ref = _perfilRef(usuario.uid);
    final doc = await ref.get();
    if (doc.exists) {
      await _registrarAcceso(usuario);
      return;
    }
    final partes = (usuario.displayName ?? '').trim().split(RegExp(r'\s+'));
    final perfil = PerfilUsuario(
      uid: usuario.uid,
      email: (usuario.email ?? '').toLowerCase(),
      nombre: partes.isNotEmpty ? partes.first : '',
      apellido: partes.length > 1 ? partes.sublist(1).join(' ') : '',
      telefono: usuario.phoneNumber ?? '',
      fotoUrl: usuario.photoURL,
      proveedor: proveedor,
    );
    await ref.set(perfil.aFirestoreNuevo());
  }

  Future<void> _registrarAcceso(User usuario) async {
    try {
      await _perfilRef(usuario.uid).set(
        {'ultimoAcceso': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      // No impide entrar a la app (por ejemplo, sin conexión).
      debugPrint('No se pudo registrar el último acceso: ${e.code}');
    }
  }

  Future<void> cerrarSesion() async {
    if (!kIsWeb) {
      final proveedores = _auth.currentUser?.providerData.map((p) => p.providerId).toSet() ?? {};
      if (proveedores.contains('google.com')) {
        await GoogleSignIn.instance.signOut().catchError((_) {});
      }
      if (proveedores.contains('facebook.com') && AuthConfig.facebookConfigurado) {
        await FacebookAuth.instance.logOut().catchError((_) {});
      }
    }
    await _auth.signOut();
  }

  static bool _esCancelacion(String codigo) =>
      codigo == 'popup-closed-by-user' ||
      codigo == 'cancelled-popup-request' ||
      codigo == 'web-context-canceled';

  /// Traduce los códigos de Firebase Authentication a mensajes que dicen qué hacer.
  static String mensajeDeError(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos. Revísalos e inténtalo de nuevo.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada. Escríbenos si crees que es un error.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo. Inicia sesión o recupera tu contraseña.';
      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 8 caracteres con letras y números.';
      case 'too-many-requests':
        return 'Hiciste demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'No hay conexión a internet. Revísala e inténtalo de nuevo.';
      case 'account-exists-with-different-credential':
        return 'Ya tienes una cuenta con este correo usando otro método. Entra con ese método.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está activado en Firebase todavía.';
      case 'popup-blocked':
        return 'El navegador bloqueó la ventana emergente. Permítela e inténtalo de nuevo.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión y repite la acción.';
      default:
        return 'Ocurrió un error inesperado ($codigo). Inténtalo de nuevo.';
    }
  }
}
