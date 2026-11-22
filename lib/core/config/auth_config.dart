/// Claves públicas de los proveedores de inicio de sesión.
///
/// Estos valores NO son secretos (van dentro de la app), pero cada equipo debe
/// ponerlos después de configurar Firebase. Paso a paso en docs/autenticacion.md.
class AuthConfig {
  AuthConfig._();

  /// ID de cliente web de OAuth de Google (termina en `.apps.googleusercontent.com`).
  ///
  /// Firebase Console → Authentication → Método de acceso → Google →
  /// «Configuración del SDK web» → «ID de cliente web».
  ///
  /// En Android no hace falta si el `google-services.json` descargado después de
  /// activar Google ya trae el cliente web (`oauth_client` con `client_type: 3`).
  /// Si queda vacío y el archivo no lo trae, el botón de Google muestra un aviso.
  static const String googleServerClientId = '';

  /// `true` cuando ya se creó la app en Meta for Developers y se pusieron el
  /// App ID y el Client Token en android/app/src/main/res/values/strings.xml
  /// (y en ios/Runner/Info.plist). Mientras sea `false`, el botón de Facebook
  /// explica qué falta en vez de abrir una pantalla de error de Facebook.
  static const bool facebookConfigurado = false;
}
