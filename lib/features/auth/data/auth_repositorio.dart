import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/perfil_usuario.dart';

/// Error de inicio de sesión con un mensaje listo para mostrar al usuario.
class ErrorAuth implements Exception {
  const ErrorAuth(this.mensaje, {this.codigo});

  final String mensaje;
  final String? codigo;

  @override
  String toString() => mensaje;
}

/// Cuentas de usuario (Firebase Authentication) y su perfil (Cloud Firestore).
///
/// - Correo y contraseña: registro, inicio de sesión y recuperación por correo.
/// - Cada cuenta tiene su documento `users/{uid}` con los datos del registro.
class AuthRepositorio {
  AuthRepositorio({FirebaseAuth? auth, FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functionsInyectadas = functions;

  static final AuthRepositorio instancia = AuthRepositorio();

  /// Tiempo máximo para guardar el perfil antes de avisar que no hay conexión.
  static const tiempoMaximoPerfil = Duration(seconds: 20);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsInyectadas;

  FirebaseFunctions get _functions => _functionsInyectadas ?? FirebaseFunctions.instance;

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
      // Sin conexión, Firestore espera indefinidamente a que el servidor
      // confirme; con el límite de tiempo el usuario no se queda cargando.
      await _perfilRef(usuario.uid).set(perfil.aFirestoreNuevo()).timeout(tiempoMaximoPerfil);
    } on Object catch (e) {
      // La cuenta quedó creada pero sin perfil: se borra para que pueda
      // registrarse de nuevo con el mismo correo.
      await usuario.delete().catchError((_) {});
      final codigo = e is FirebaseException ? e.code : (e is TimeoutException ? 'timeout' : 'desconocido');
      throw ErrorAuth(
        'No se pudieron guardar tus datos ($codigo). Revisa tu conexión e inténtalo de nuevo.',
        codigo: codigo,
      );
    }

    // El perfil ya está guardado: si solo falla el nombre visible de
    // Firebase Authentication, la cuenta sigue siendo válida.
    try {
      await usuario.updateDisplayName(perfil.nombreCompleto);
    } on Object catch (e) {
      debugPrint('No se pudo actualizar el nombre visible: $e');
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
  // Perfil y sesión
  // ---------------------------------------------------------------------------

  /// Actualiza los datos que el usuario puede editar en Perfil.
  Future<void> actualizarPerfil(
    String uid, {
    required String nombre,
    required String apellido,
    required String telefono,
    required String ciudad,
    required Preferencias preferencias,
  }) async {
    await _perfilRef(uid).set({
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'telefono': telefono.trim(),
      'ciudad': ciudad.trim(),
      'preferencias': preferencias.aFirestore(),
    }, SetOptions(merge: true));
    final completo = [nombre.trim(), apellido.trim()].where((p) => p.isNotEmpty).join(' ');
    try {
      await _auth.currentUser?.updateDisplayName(completo);
    } on Object catch (e) {
      debugPrint('No se pudo actualizar el nombre visible: $e');
    }
  }

  /// Elimina la cuenta y TODOS sus datos (Ley 1581: derecho de supresión).
  /// Lo hace la Cloud Function `eliminarCuenta`; luego se cierra la sesión.
  Future<void> eliminarCuenta() async {
    try {
      await _functions
          .httpsCallable('eliminarCuenta', options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
          .call({'confirmacion': 'ELIMINAR'});
    } on FirebaseFunctionsException catch (e) {
      throw ErrorAuth(e.message ?? 'No se pudo eliminar la cuenta. Inténtalo de nuevo.', codigo: e.code);
    }
    await cerrarSesion().catchError((_) {});
  }

  /// Guarda la autorización de tratamiento de datos (la pide AuthGate a las
  /// cuentas que aún no la tienen o tienen una versión anterior del texto).
  Future<void> aceptarConsentimiento(String uid) {
    return _perfilRef(uid).set(
      {'consentimientoDatos': const ConsentimientoDatos(aceptado: true).aFirestore()},
      SetOptions(merge: true),
    );
  }

  /// Crea `users/{uid}` con los datos de la cuenta si todavía no existe.
  /// También lo usa `AuthGate` para recuperar cuentas que quedaron sin perfil.
  Future<void> crearPerfilSiFalta(User usuario, {String? proveedor}) async {
    final ref = _perfilRef(usuario.uid);
    final doc = await ref.get().timeout(tiempoMaximoPerfil);
    if (doc.exists) {
      await _registrarAcceso(usuario);
      return;
    }
    proveedor ??= usuario.providerData.isNotEmpty ? usuario.providerData.first.providerId : 'password';
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
    await ref.set(perfil.aFirestoreNuevo()).timeout(tiempoMaximoPerfil);
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

  Future<void> cerrarSesion() => _auth.signOut();

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
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión y repite la acción.';
      default:
        return 'Ocurrió un error inesperado ($codigo). Inténtalo de nuevo.';
    }
  }
}
