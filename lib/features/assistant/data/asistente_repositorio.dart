import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/mensaje.dart';

/// Respuesta de la Cloud Function `chat`.
class RespuestaAsistente {
  const RespuestaAsistente({
    required this.texto,
    required this.rechazado,
    this.conversacionId,
  });

  final String texto;
  final bool rechazado;
  final String? conversacionId;
}

/// Conecta la pantalla del chat con el backend del asistente y con Firestore.
///
/// - Enviar: llama a la Cloud Function `chat`. La función lee el armario del
///   usuario en Firestore, le pregunta a Gemini y guarda la pregunta y la
///   respuesta en `users/{uid}/conversaciones`.
/// - Cargar: lee el historial de la última conversación desde Firestore.
class AsistenteRepositorio {
  AsistenteRepositorio({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// El asistente necesita un usuario con sesión iniciada.
  /// Mientras no exista la pantalla de inicio de sesión (módulo `auth`),
  /// se entra de forma anónima. Requiere activar "Anónimo" en
  /// Firebase Console → Authentication → Método de acceso.
  Future<String> _uid() async {
    final actual = _auth.currentUser;
    if (actual != null) return actual.uid;
    final credencial = await _auth.signInAnonymously();
    return credencial.user!.uid;
  }

  Future<CollectionReference<Map<String, dynamic>>> _conversaciones() async {
    final uid = await _uid();
    return _firestore.collection('users').doc(uid).collection('conversaciones');
  }

  /// Id de la conversación con actividad más reciente, o `null` si no hay.
  Future<String?> ultimaConversacionId() async {
    final consulta = await (await _conversaciones())
        .orderBy('ultimaActividad', descending: true)
        .limit(1)
        .get();
    return consulta.docs.isEmpty ? null : consulta.docs.first.id;
  }

  /// Mensajes guardados de una conversación, del más antiguo al más reciente.
  Future<List<Mensaje>> cargarMensajes(String conversacionId) async {
    final consulta = await (await _conversaciones())
        .doc(conversacionId)
        .collection('mensajes')
        .orderBy('fecha')
        .get();
    return consulta.docs.map((d) => Mensaje.desdeFirestore(d.data())).toList();
  }

  /// Envía el historial a la Cloud Function. El último mensaje debe ser del usuario.
  Future<RespuestaAsistente> enviar({
    required List<Mensaje> historial,
    String? conversacionId,
  }) async {
    await _uid();
    final resultado = await _functions
        .httpsCallable(
          'chat',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({
      'mensajes': historial.map((m) => m.aFuncion()).toList(),
      if (conversacionId != null) 'conversacionId': conversacionId,
    });
    final datos = Map<String, dynamic>.from(resultado.data as Map);
    return RespuestaAsistente(
      texto: (datos['texto'] as String?) ?? '',
      rechazado: datos['rechazado'] == true,
      conversacionId: datos['conversacionId'] as String?,
    );
  }
}
