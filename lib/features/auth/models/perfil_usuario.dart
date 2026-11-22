import 'package:cloud_firestore/cloud_firestore.dart';

/// Versión del texto de autorización de tratamiento de datos (Ley 1581 de 2012).
/// Si cambia el texto, se sube la versión y la app vuelve a pedir la autorización.
const versionConsentimiento = '1.0';

/// Autorización de tratamiento de datos personales que dio el usuario.
class ConsentimientoDatos {
  const ConsentimientoDatos({
    required this.aceptado,
    this.fecha,
    this.version = versionConsentimiento,
  });

  final bool aceptado;
  final DateTime? fecha;
  final String version;

  /// `true` si el usuario aceptó la versión vigente del texto.
  bool get vigente => aceptado && version == versionConsentimiento;

  factory ConsentimientoDatos.desdeMapa(dynamic datos) {
    if (datos is! Map) return const ConsentimientoDatos(aceptado: false);
    final fecha = datos['fecha'];
    return ConsentimientoDatos(
      aceptado: datos['aceptado'] == true,
      fecha: fecha is Timestamp ? fecha.toDate() : null,
      version: datos['version'] is String ? datos['version'] as String : '',
    );
  }

  /// Mapa para Firestore. La fecha la pone el servidor para que no dependa del reloj del celular.
  Map<String, dynamic> aFirestore() => {
        'aceptado': aceptado,
        'fecha': FieldValue.serverTimestamp(),
        'version': version,
      };
}

/// Estilos, colores y ocasiones favoritas del usuario (las usa el asistente y el generador).
class Preferencias {
  const Preferencias({
    this.estilos = const [],
    this.colores = const [],
    this.ocasiones = const [],
  });

  final List<String> estilos;
  final List<String> colores;
  final List<String> ocasiones;

  static List<String> _lista(dynamic v) =>
      v is List ? v.whereType<String>().toList() : const [];

  factory Preferencias.desdeMapa(dynamic datos) {
    if (datos is! Map) return const Preferencias();
    return Preferencias(
      estilos: _lista(datos['estilos']),
      colores: _lista(datos['colores']),
      ocasiones: _lista(datos['ocasiones']),
    );
  }

  Map<String, dynamic> aFirestore() => {
        'estilos': estilos,
        'colores': colores,
        'ocasiones': ocasiones,
      };
}

/// Perfil del usuario en Cloud Firestore: `users/{uid}`.
///
/// Es el documento raíz de cada usuario; debajo cuelgan sus subcolecciones
/// (prendas, outfits, conversaciones, etc.). Ver docs/base-de-datos.md.
class PerfilUsuario {
  const PerfilUsuario({
    required this.uid,
    required this.email,
    this.nombre = '',
    this.apellido = '',
    this.telefono = '',
    this.ciudad = '',
    this.fotoUrl,
    this.proveedor = 'password',
    this.rol = 'usuario',
    this.locale = 'es-CO',
    this.preferencias = const Preferencias(),
    this.consentimiento = const ConsentimientoDatos(aceptado: false),
    this.fechaRegistro,
    this.ultimoAcceso,
  });

  final String uid;
  final String email;
  final String nombre;
  final String apellido;
  final String telefono;
  final String ciudad;
  final String? fotoUrl;

  /// Cómo se registró: `password`, `google.com` o `facebook.com`.
  final String proveedor;

  /// `usuario` o `admin`. Solo un administrador puede cambiarlo (ver firestore.rules).
  final String rol;
  final String locale;
  final Preferencias preferencias;
  final ConsentimientoDatos consentimiento;
  final DateTime? fechaRegistro;
  final DateTime? ultimoAcceso;

  String get nombreCompleto => [nombre, apellido].where((p) => p.trim().isNotEmpty).join(' ');

  /// Nombre para saludar: el nombre, o la parte del correo antes de la @.
  String get nombreCorto {
    if (nombre.trim().isNotEmpty) return nombre.trim().split(' ').first;
    final usuario = email.split('@').first;
    return usuario.isEmpty ? '' : usuario;
  }

  static String _texto(dynamic v) => v is String ? v.trim() : '';
  static DateTime? _fecha(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory PerfilUsuario.desdeFirestore(String uid, Map<String, dynamic> datos) {
    return PerfilUsuario(
      uid: uid,
      email: _texto(datos['email']),
      nombre: _texto(datos['nombre']),
      apellido: _texto(datos['apellido']),
      telefono: _texto(datos['telefono']),
      ciudad: _texto(datos['ciudad']),
      fotoUrl: datos['fotoUrl'] is String ? datos['fotoUrl'] as String : null,
      proveedor: _texto(datos['proveedor']).isEmpty ? 'password' : _texto(datos['proveedor']),
      rol: datos['rol'] == 'admin' ? 'admin' : 'usuario',
      locale: _texto(datos['locale']).isEmpty ? 'es-CO' : _texto(datos['locale']),
      preferencias: Preferencias.desdeMapa(datos['preferencias']),
      consentimiento: ConsentimientoDatos.desdeMapa(datos['consentimientoDatos']),
      fechaRegistro: _fecha(datos['fechaRegistro']),
      ultimoAcceso: _fecha(datos['ultimoAcceso']),
    );
  }

  /// Datos del documento nuevo. `rol` siempre empieza como `usuario`.
  Map<String, dynamic> aFirestoreNuevo() => {
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'ciudad': ciudad,
        'fotoUrl': fotoUrl,
        'proveedor': proveedor,
        'rol': 'usuario',
        'locale': locale,
        'preferencias': preferencias.aFirestore(),
        if (consentimiento.aceptado) 'consentimientoDatos': consentimiento.aFirestore(),
        'fechaRegistro': FieldValue.serverTimestamp(),
        'ultimoAcceso': FieldValue.serverTimestamp(),
      };
}
