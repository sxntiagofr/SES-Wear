// Los dobles de prueba implementan clases selladas de Firebase a propósito.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable

// Dobles de prueba de Firebase para los tests de auditoría.
// Permiten probar repositorios y pantallas sin inicializar Firebase.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart' show Schema;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ses_wear/core/ia/servicio_ia.dart';

class FakeUser extends Fake implements User {
  FakeUser({
    this.uid = 'u1',
    this.email = 'ana@correo.com',
    this.isAnonymous = false,
    this.displayName,
    this.errorAlActualizarNombre,
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final bool isAnonymous;
  @override
  String? displayName;
  @override
  String? get phoneNumber => null;
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => const [];

  final Object? errorAlActualizarNombre;
  bool borrado = false;

  @override
  Future<void> delete() async => borrado = true;

  @override
  Future<void> updateDisplayName(String? displayName) async {
    if (errorAlActualizarNombre != null) throw errorAlActualizarNombre!;
    this.displayName = displayName;
  }
}

class FakeCred extends Fake implements UserCredential {
  FakeCred(this.user);
  @override
  final User? user;
}

class FakeAuth extends Fake implements FirebaseAuth {
  FakeAuth({this.currentUser, this.errorLogin, this.errorRegistro, this.errorReset, FakeUser? nuevo})
      : nuevo = nuevo ?? FakeUser();

  @override
  User? currentUser;
  final FirebaseAuthException? errorLogin;
  final FirebaseAuthException? errorRegistro;
  final FirebaseAuthException? errorReset;
  final FakeUser nuevo;

  String? ultimoCorreo;
  bool creoCuenta = false;
  final _cambios = StreamController<User?>.broadcast();

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    ultimoCorreo = email;
    if (errorLogin != null) throw errorLogin!;
    currentUser = nuevo;
    return FakeCred(nuevo);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    ultimoCorreo = email;
    if (errorRegistro != null) throw errorRegistro!;
    creoCuenta = true;
    currentUser = nuevo;
    return FakeCred(nuevo);
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email, ActionCodeSettings? actionCodeSettings}) async {
    ultimoCorreo = email;
    if (errorReset != null) throw errorReset!;
  }

  @override
  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* _cambios.stream;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _cambios.add(null);
  }
}

/// Firestore en memoria muy simple: guarda lo que se escribe con `set`.
class FakeFirestore extends Fake implements FirebaseFirestore {
  FakeFirestore({this.errorAlEscribir});

  final Object? errorAlEscribir;
  final Map<String, Map<String, dynamic>> docs = {};
  final Map<String, StreamController<DocumentSnapshot<Map<String, dynamic>>>> _streams = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      FakeCollection(this, collectionPath);

  StreamController<DocumentSnapshot<Map<String, dynamic>>> streamDe(String path) =>
      _streams.putIfAbsent(path, () => StreamController.broadcast());
}

class FakeCollection extends Fake implements CollectionReference<Map<String, dynamic>> {
  FakeCollection(this.db, this.path);
  final FakeFirestore db;
  @override
  final String path;
  int _contador = 0;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      FakeDoc(db, '$path/${id ?? 'auto${_contador++}'}');
}

class FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  FakeDoc(this.db, this.path);
  final FakeFirestore db;
  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (db.errorAlEscribir != null) throw db.errorAlEscribir!;
    final previo = (options?.merge ?? false) ? (db.docs[path] ?? {}) : <String, dynamic>{};
    db.docs[path] = {...previo, ...data};
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async =>
      FakeSnap(id, db.docs[path]);

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield FakeSnap(id, db.docs[path]);
    yield* db.streamDe(path).stream;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      FakeCollection(db, '$path/$collectionPath');
}

class FakeSnap extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  FakeSnap(this.id, this._datos);
  @override
  final String id;
  final Map<String, dynamic>? _datos;
  @override
  bool get exists => _datos != null;
  @override
  Map<String, dynamic>? data() => _datos;
}

class FakeFunctions extends Fake implements FirebaseFunctions {
  FakeFunctions([Map<String, Object? Function(dynamic datos)>? respuestas]) : respuestas = respuestas ?? {};

  /// Respuesta de cada función por nombre. Si lanza, la llamada falla con ese error.
  final Map<String, Object? Function(dynamic datos)> respuestas;
  final llamadas = <(String, dynamic)>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) => FakeCallable(this, name);
}

class FakeCallable extends Fake implements HttpsCallable {
  FakeCallable(this.funciones, this.nombre);
  final FakeFunctions funciones;
  final String nombre;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    funciones.llamadas.add((nombre, parameters));
    final respuesta = funciones.respuestas[nombre];
    if (respuesta == null) throw StateError('Función no simulada: $nombre');
    return FakeResultado<T>(respuesta(parameters) as T);
  }
}

class FakeResultado<T> extends Fake implements HttpsCallableResult<T> {
  FakeResultado(this.data);
  @override
  final T data;
}

class FakeStorage extends Fake implements FirebaseStorage {}

/// IA falsa: devuelve respuestas fijas y guarda lo que se le pidió.
class IAFalsa implements ServicioIA {
  IAFalsa({this.texto = 'Respuesta de la IA', this.json = const {}, this.error});

  final String texto;
  final Map<String, dynamic> json;
  final Object? error;
  final conversaciones = <({String instrucciones, List<TurnoIA> historial})>[];
  final pedidosJson = <({String instrucciones, TurnoIA pedido})>[];

  @override
  Future<RespuestaIA> conversar({required String instrucciones, required List<TurnoIA> historial}) async {
    conversaciones.add((instrucciones: instrucciones, historial: historial));
    if (error != null) throw error!;
    return RespuestaIA(texto: texto);
  }

  @override
  Future<Map<String, dynamic>> generarJson({
    required String instrucciones,
    required TurnoIA pedido,
    required Schema esquema,
    double temperatura = 0.2,
  }) async {
    pedidosJson.add((instrucciones: instrucciones, pedido: pedido));
    if (error != null) throw error!;
    return json;
  }
}
