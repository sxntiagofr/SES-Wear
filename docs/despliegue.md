# Puesta en marcha, pruebas y despliegue

Esta guía cubre lo que hay que hacer **en la consola de Firebase y en cada PC** para que la app funcione completa. El código ya está listo; estos pasos necesitan las cuentas del equipo y no se pueden automatizar desde el repositorio.

## 1. Programas en el PC

| Programa | Para qué | Cómo comprobar |
|---|---|---|
| Flutter SDK | compilar la app | `flutter --version` |
| Git (en el PATH) | Flutter lo necesita | `git --version` |
| Node.js 22 | Cloud Functions y pruebas | `node -v` |
| Firebase CLI | desplegar y emuladores | `firebase --version` (instalar con `npm i -g firebase-tools`) |
| Java 21 (OpenJDK) | emuladores de Firestore/Storage | `java -version` |
| Android Studio + Android SDK | compilar el APK y probar en Android | `flutter doctor` sin ❌ en *Android toolchain* |

En Windows, Node y Java se instalan con `winget install OpenJS.NodeJS.22` y `winget install Microsoft.OpenJDK.21`.

## 2. Activar la IA (Firebase AI Logic) — sin tarjeta ni API key

El asistente, la identificación de prendas y las "Ideas con IA" llaman a Gemini **desde la app** con Firebase AI Logic. Funciona en el plan gratuito Spark.

1. Firebase Console → proyecto `ses-wear` → **AI Logic** (menú *Compilación* / *Build*) → **Comenzar**.
2. Elegir el proveedor **Gemini Developer API** y confirmar. Firebase crea y guarda la clave; no hay que copiarla en ningún lado.
3. (Recomendado) En AI Logic → *Configuración*, poner un **límite de solicitudes por usuario** (p. ej. 20 por minuto) para que nadie agote el cupo gratuito.

Mientras no se haga, el chat y la identificación muestran: *"La IA todavía no está activada en Firebase (AI Logic)"*.

Los modelos se configuran en `lib/core/ia/servicio_ia.dart` (`gemini-flash-latest` y, de respaldo, `gemini-flash-lite-latest`).

## 3. Quitar el fondo (remove.bg) y eliminar cuenta: Cloud Functions

Solo dos funciones necesitan servidor: `quitarFondo` (la clave de remove.bg no puede ir en la app) y `eliminarCuenta`.

1. Pasar el proyecto `ses-wear` al plan **Blaze** (las funciones llaman una API externa). El uso de este proyecto queda dentro del nivel gratuito.
2. `firebase login`
3. Crear la clave en <https://www.remove.bg/dashboard#api-key> (50 fotos gratis al mes) y ponerla en `functions/.secret.local` (copia de `.secret.local.example`).
4. Ejecutar el script, que sube la clave a Secret Manager y despliega reglas, índices y funciones:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\configurar-claves.ps1
   ```

Después de cambiar reglas o funciones basta con:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Mientras no estén publicadas, al tomar una foto la app avisa *"El servicio para quitar el fondo aún no está publicado en el servidor"* y deja guardar la prenda con la foto original.

## 4. App Check (protege los cupos de IA)

La app ya activa App Check en Android e iOS (`lib/main.dart`) y el servidor ya limita a cada usuario a un número de usos diarios (`functions/src/limites.js`). Para exigir que **solo la app oficial** pueda llamar las funciones:

1. Firebase Console → **App Check** → registrar la app Android con **Play Integrity** (pide la huella SHA-256).
2. Para probar en modo debug: correr la app, copiar el *debug token* que aparece en la consola (`Enter this debug secret into the allow list…`) y agregarlo en App Check → *Administrar tokens de depuración*.
3. Crear `functions/.env` con la línea `EXIGIR_APP_CHECK=true` y volver a desplegar las funciones.
4. (Opcional) En App Check, activar la verificación obligatoria para Firestore y Storage.

No activar el paso 3 antes de completar el 1 y el 2: las funciones rechazarían todas las llamadas.

## 5. Probar todo en el PC, sin tocar los datos reales

### Pruebas automáticas

```bash
flutter analyze                       # debe decir "No issues found!"
flutter test                          # app: lógica y pantallas
cd functions && npm test              # Cloud Functions (lógica, sin internet)
cd test-firebase && npm install && npm test   # reglas + funciones con los emuladores
```

`test-firebase` levanta los emuladores con `firebase.pruebas.json` (puertos 8180, 9299, 9399 y 5101), así que no choca con otros emuladores abiertos.

### La app completa con los emuladores

```bash
firebase emulators:start --project ses-wear   # mismo id que usa la app; no toca los datos reales
flutter run --dart-define=USAR_EMULADORES=true
```

Si el puerto 8080 ya está ocupado (otro programa), cerrar ese programa o cambiar el puerto de Firestore en `firebase.json` y en `_conectarEmuladores` de `lib/main.dart`.

Con `USAR_EMULADORES=true` la app usa Auth, Firestore, Storage y Functions locales (en el emulador de Android se conectan por `10.0.2.2`). La IA (chat e identificación de prendas) usa siempre el proyecto real con Firebase AI Logic; quitar el fondo en el emulador necesita la clave de remove.bg en `functions/.secret.local`. Sin ellas se muestra un error controlado y el resto de la app funciona igual. Lo que falta configurar está en [`pendientes.md`](pendientes.md).

### Lista de verificación manual (antes de la entrega)

1. Registrarse con correo, aceptar la autorización de datos y cerrar/abrir la app (la sesión se conserva).
2. Agregar una prenda con foto: la IA llena el formulario; probar **Quitar fondo**.
3. En el armario: buscar, filtrar por tipo/color/estación, abrir el detalle, **Editar** (poner precio) y **La usé hoy**.
4. Crear una colección, elegir prendas y **Generar outfits con esta colección**.
5. En Outfits: generar, **Otras opciones**, **Ideas con IA**, guardar, marcar favorito y calificar.
6. Planear un outfit en el calendario y verlo en **Inicio → Outfit del día**.
7. Revisar **Estadísticas** (más usadas, desuso, costo por uso, paleta).
8. Preguntarle al asistente qué ponerse con lo que hay en el armario.
9. Perfil: editar datos y preferencias, cambiar a modo claro/oscuro.
10. **Eliminar cuenta** (con una cuenta de prueba) y comprobar en la consola que no quedó nada en Firestore, Storage ni Authentication.

## 6. APK para la entrega

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Para la versión final hay que firmarla con la llave de release (y agregar su SHA-1 y SHA-256 en Firebase, pasos 3 y 4).
