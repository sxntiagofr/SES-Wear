# Autenticación (RF-01.1)

> **Actualización:** el inicio de sesión con Google y Facebook se retiró de la app. Solo queda correo y contraseña; las secciones de Google y Facebook de este documento quedan como referencia histórica.

Módulo `lib/features/auth/`. Cubre:

| Función | Pantalla | Firebase |
|---|---|---|
| Iniciar sesión con correo y contraseña | `login_screen.dart` | `signInWithEmailAndPassword` |
| Crear cuenta (nombre, apellido, teléfono, correo, contraseña y autorización de datos) | `registro_screen.dart` | `createUserWithEmailAndPassword` + documento `users/{uid}` |
| ¿Olvidaste tu contraseña? | `recuperar_contrasena_screen.dart` | `sendPasswordResetEmail` (correo en español) |
| Seguir con la sesión abierta | `auth_gate.dart` | `authStateChanges()`: si ya entró antes, abre directo en Inicio |
| Google | botón «G» | `google_sign_in` (Android/iOS) o ventana emergente (web) |
| Facebook | botón de Facebook | `flutter_facebook_auth` (Android/iOS) o ventana emergente (web) |
| Autorización de datos (Ley 1581) | casilla en el registro; pantalla aparte la primera vez con Google/Facebook | campo `consentimientoDatos` |
| Cerrar sesión | pestaña Perfil | `signOut` |

Flujo: `main.dart` → `AuthGate` → sin sesión: **Iniciar sesión** · con sesión sin autorización: **Autorización de datos** · con todo: **la app**.

Los textos de error dicen qué hacer (`AuthRepositorio.mensajeDeError`). La contraseña nueva pide mínimo 8 caracteres con letras y números; la app nunca la guarda (la maneja Firebase Authentication).

---

## Configuración en Firebase (una sola vez)

Proyecto: <https://console.firebase.google.com/project/ses-wear/overview>

### 1. Correo y contraseña
1. **Authentication → Método de acceso → Agregar proveedor nuevo → Correo electrónico/contraseña → Habilitar → Guardar.**
2. **Authentication → Plantillas →** ícono de idioma → **Español**, para que el correo de «restablecer contraseña» llegue en español.
3. (Opcional) Puede desactivarse el proveedor **Anónimo**: la app ya no lo usa.

### 2. Google
1. **Authentication → Método de acceso → Google → Habilitar**, elegir el correo de asistencia y **Guardar**.
2. En ese mismo panel, abrir **Configuración del SDK web** y copiar el **ID de cliente web** (termina en `.apps.googleusercontent.com`). Pegarlo en `lib/core/config/auth_config.dart` → `googleServerClientId`.
3. Cada integrante saca la huella **SHA-1** de su llave de depuración y la agrega en **Configuración del proyecto → Tus apps → Android (com.example.ses_wear) → Agregar huella digital**:
   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
   (Para el APK de la entrega se agrega también la SHA-1 de la llave de firma de release.)
4. Volver a descargar `google-services.json` y reemplazar `android/app/google-services.json`.

### 3. Facebook
1. En <https://developers.facebook.com> → **Mis apps → Crear app** (tipo *Consumidor* / *Autenticar usuarios*). Agregar el producto **Inicio de sesión con Facebook**.
2. En Facebook → **Configuración → Básica**: copiar **App ID** y **Clave secreta**.
3. En Firebase → **Authentication → Método de acceso → Facebook → Habilitar**, pegar App ID y Clave secreta, copiar la **URI de redireccionamiento de OAuth** que muestra Firebase y pegarla en Facebook → **Inicio de sesión con Facebook → Configuración → URI de redireccionamiento de OAuth válidos**.
4. En Facebook → **Configuración → Básica → Agregar plataforma → Android**: paquete `com.example.ses_wear`, clase `com.example.ses_wear.MainActivity` y los *key hashes* de cada integrante.
5. En Facebook → **Configuración → Avanzada**: copiar el **Client Token**.
6. Poner App ID y Client Token en `android/app/src/main/res/values/strings.xml` y cambiar `facebookConfigurado` a `true` en `lib/core/config/auth_config.dart`.
7. Mientras la app de Meta esté en **modo desarrollo**, solo pueden entrar las cuentas agregadas como *evaluadores* en Facebook.

### 4. iOS (solo si hay un Mac)
Agregar en `ios/Runner/Info.plist` el `CFBundleURLTypes` con el `REVERSED_CLIENT_ID` de `GoogleService-Info.plist`, y las claves `FacebookAppID`, `FacebookClientToken`, `FacebookDisplayName` y el esquema `fb{App ID}` (instrucciones de los paquetes `google_sign_in` y `flutter_facebook_auth`).

### 5. Reglas de la base de datos
Publicar las reglas de `firestore.rules` (impiden que alguien se ponga el rol de administrador o lea datos de otro usuario):
```powershell
firebase deploy --only firestore:rules,storage
```
También se pueden copiar y pegar en **Firestore Database → Reglas → Publicar**.

---

## Administradores (RF-08.1)
El rol de administrador es un *custom claim* `admin: true` que solo se asigna desde el servidor (Admin SDK), nunca desde la app:
```js
// node, con credenciales del proyecto
await admin.auth().setCustomUserClaims(uid, { admin: true });
await admin.firestore().doc(`users/${uid}`).update({ rol: "admin" });
```
