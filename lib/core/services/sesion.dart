import 'package:firebase_auth/firebase_auth.dart';

/// Sesión del usuario actual.
///
/// Mientras no exista la pantalla de inicio de sesión (módulo `auth`), si no hay
/// usuario se entra de forma anónima. Requiere activar "Anónimo" en
/// Firebase Console → Authentication → Método de acceso.
class Sesion {
  Sesion._();

  static Future<String> uid([FirebaseAuth? auth]) async {
    final instancia = auth ?? FirebaseAuth.instance;
    final actual = instancia.currentUser;
    if (actual != null) return actual.uid;
    final credencial = await instancia.signInAnonymously();
    return credencial.user!.uid;
  }
}
