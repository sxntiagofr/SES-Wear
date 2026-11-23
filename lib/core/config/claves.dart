/// Claves opcionales de servicios de IA, leídas al compilar la app.
///
/// Se ponen en `claves.json` (en la raíz del proyecto, NO se sube a GitHub) y
/// la app se ejecuta con:
///
///   flutter run --dart-define-from-file=claves.json
///
/// En VS Code basta con elegir la configuración «SES Wear» y pulsar F5
/// (.vscode/launch.json ya pasa el archivo).
///
/// - `GEMINI_API_KEY`: si está, el asistente y la identificación de prendas
///   llaman a Gemini directamente con esa clave. Si está vacía, usan
///   Firebase AI Logic (hay que activarlo en la consola de Firebase).
/// - `REMOVE_BG_API_KEY`: si está, la app quita el fondo de las fotos llamando
///   a remove.bg directamente. Si está vacía, usa la Cloud Function
///   `quitarFondo` (necesita el plan Blaze).
///
/// Aviso: una clave que va dentro de la app se puede extraer del APK. Para un
/// proyecto académico está bien; en producción conviene usar Firebase AI Logic
/// y la Cloud Function, que guardan las claves en el servidor.
class Claves {
  const Claves._();

  static const gemini = String.fromEnvironment('GEMINI_API_KEY');
  static const removeBg = String.fromEnvironment('REMOVE_BG_API_KEY');

  static bool get hayGemini => _valida(gemini);
  static bool get hayRemoveBg => _valida(removeBg);

  static bool _valida(String clave) => clave.trim().isNotEmpty && !clave.startsWith('PEGA_AQUI');
}
