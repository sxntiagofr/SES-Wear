import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/services/sesion.dart';
import '../../auth/models/perfil_usuario.dart';
import '../../wardrobe/models/prenda.dart';
import '../logic/asistente_ia.dart';
import '../models/mensaje.dart';

/// Respuesta del asistente.
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

/// Conecta la pantalla del chat con Gemini (Firebase AI Logic) y con Firestore.
///
/// - Enviar: lee el perfil y el armario del usuario, se los da a Gemini como
///   contexto junto con la conversación y guarda la pregunta y la respuesta en
///   `users/{uid}/conversaciones/{id}/mensajes`.
/// - Cargar: lee el historial de la última conversación.
class AsistenteRepositorio {
  AsistenteRepositorio({ServicioIA? ia, FirebaseFirestore? firestore, this._auth})
      : _iaInyectada = ia,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final ServicioIA? _iaInyectada;
  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  ServicioIA get _ia => _iaInyectada ?? ServicioIAFirebase.instancia;

  Future<String> _uid() => Sesion.uid(_auth);

  DocumentReference<Map<String, dynamic>> _usuario(String uid) => _firestore.collection('users').doc(uid);

  /// Id de la conversación con actividad más reciente, o `null` si no hay.
  Future<String?> ultimaConversacionId() async {
    final consulta = await _usuario(await _uid())
        .collection('conversaciones')
        .orderBy('ultimaActividad', descending: true)
        .limit(1)
        .get();
    return consulta.docs.isEmpty ? null : consulta.docs.first.id;
  }

  /// Mensajes guardados de una conversación, del más antiguo al más reciente.
  Future<List<Mensaje>> cargarMensajes(String conversacionId) async {
    final consulta = await _usuario(await _uid())
        .collection('conversaciones')
        .doc(conversacionId)
        .collection('mensajes')
        .orderBy('fecha')
        .get();
    return consulta.docs.map((d) => Mensaje.desdeFirestore(d.data())).toList();
  }

  /// Perfil y prendas para el contexto. Si falla, el asistente responde sin él.
  Future<String> _contexto(String uid) async {
    try {
      final usuario = _usuario(uid);
      final resultados = await Future.wait([
        usuario.get(),
        usuario.collection('prendas').limit(AsistenteIA.maxPrendasEnContexto + 1).get(),
      ]);
      final perfilDoc = resultados[0] as DocumentSnapshot<Map<String, dynamic>>;
      final prendasDocs = resultados[1] as QuerySnapshot<Map<String, dynamic>>;
      final perfil = perfilDoc.data() == null ? null : PerfilUsuario.desdeFirestore(uid, perfilDoc.data()!);
      final prendas = prendasDocs.docs.map((d) => Prenda.desdeFirestore(d.id, d.data())).toList();
      return AsistenteIA.contexto(perfil, prendas);
    } catch (e) {
      debugPrint('No se pudo leer el armario para el asistente: $e');
      return '';
    }
  }

  /// Envía el historial a Gemini. El último mensaje debe ser del usuario.
  Future<RespuestaAsistente> enviar({
    required List<Mensaje> historial,
    String? conversacionId,
  }) async {
    final uid = await _uid();
    final turnos = AsistenteIA.prepararHistorial(historial);
    final contexto = await _contexto(uid);
    final respuesta = await _ia.conversar(
      instrucciones: contexto.isEmpty ? AsistenteIA.instrucciones : AsistenteIA.instruccionesCon(contexto),
      historial: turnos,
    );

    String? id = conversacionId;
    try {
      id = await _guardar(uid, conversacionId, turnos.last.texto, respuesta);
    } catch (e) {
      // La respuesta se muestra igual aunque no se pueda guardar el historial.
      debugPrint('No se pudo guardar la conversación: $e');
    }
    return RespuestaAsistente(texto: respuesta.texto, rechazado: respuesta.bloqueada, conversacionId: id);
  }

  Future<String> _guardar(String uid, String? conversacionId, String pregunta, RespuestaIA respuesta) async {
    final conversaciones = _usuario(uid).collection('conversaciones');
    final ref = conversacionId == null ? conversaciones.doc() : conversaciones.doc(conversacionId);
    final lote = _firestore.batch();
    if (conversacionId == null) {
      lote.set(ref, {
        'titulo': pregunta.length > 60 ? pregunta.substring(0, 60) : pregunta,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'ultimaActividad': FieldValue.serverTimestamp(),
      });
    } else {
      lote.set(ref, {'ultimaActividad': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    // Dos fechas distintas para que el orden sea siempre pregunta → respuesta.
    final ahora = DateTime.now();
    final mensajes = ref.collection('mensajes');
    lote.set(mensajes.doc(), {'rol': 'usuario', 'texto': pregunta, 'tieneFoto': false, 'fecha': Timestamp.fromDate(ahora)});
    lote.set(mensajes.doc(), {
      'rol': 'asistente',
      'texto': respuesta.texto,
      'rechazado': respuesta.bloqueada,
      'fecha': Timestamp.fromDate(ahora.add(const Duration(milliseconds: 1))),
    });
    await lote.commit();
    return ref.id;
  }
}
