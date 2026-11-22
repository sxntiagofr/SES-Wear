import 'package:cloud_firestore/cloud_firestore.dart';

/// Quién escribió el mensaje.
enum RolMensaje { usuario, asistente }

/// Un mensaje del chat con el asistente.
///
/// En Firestore vive en
/// `users/{uid}/conversaciones/{conversacionId}/mensajes/{mensajeId}`.
class Mensaje {
  const Mensaje({
    required this.rol,
    required this.texto,
    this.fecha,
    this.tieneFoto = false,
  });

  final RolMensaje rol;
  final String texto;
  final DateTime? fecha;
  final bool tieneFoto;

  bool get esDelUsuario => rol == RolMensaje.usuario;

  factory Mensaje.desdeFirestore(Map<String, dynamic> datos) {
    final fecha = datos['fecha'];
    return Mensaje(
      rol: datos['rol'] == 'usuario' ? RolMensaje.usuario : RolMensaje.asistente,
      texto: (datos['texto'] as String?) ?? '',
      fecha: fecha is Timestamp ? fecha.toDate() : null,
      tieneFoto: datos['tieneFoto'] == true,
    );
  }

  /// Formato que espera la Cloud Function `chat` (ver functions/README.md).
  Map<String, dynamic> aFuncion() => {
        'rol': esDelUsuario ? 'usuario' : 'asistente',
        'texto': texto,
      };
}
