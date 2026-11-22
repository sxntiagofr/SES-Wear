import 'package:firebase_auth/firebase_auth.dart';

/// Sesión del usuario actual.
///
/// La app solo muestra las pantallas internas cuando hay una cuenta con sesión
/// iniciada (ver `features/auth/screens/auth_gate.dart`), así que aquí siempre
/// debería existir un usuario. Ya no se entra de forma anónima.
class Sesion {
  Sesion._();

  static Future<String> uid([FirebaseAuth? auth]) async {
    final actual = (auth ?? FirebaseAuth.instance).currentUser;
    if (actual == null || actual.isAnonymous) {
      throw FirebaseAuthException(
        code: 'no-session',
        message: 'Debes iniciar sesión para usar esta función.',
      );
    }
    return actual.uid;
  }
}
