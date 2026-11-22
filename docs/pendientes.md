# Lo que falta para que SES Wear funcione completa

El código de la app ya está terminado y probado (`flutter test`, pruebas de Cloud Functions y de reglas pasan). Lo que falta **no es programar**: son pasos de configuración en Firebase que solo puede hacer alguien con acceso al proyecto `ses-wear`.

| # | Funcionalidad | Qué ve hoy el usuario | Qué falta | ¿Cuesta? |
|---|---|---|---|---|
| 1 | **Chat con la IA**, identificar prendas, "Ideas con IA" | *"La IA todavía no está activada en Firebase (AI Logic)"* | Activar Firebase AI Logic en la consola | No (plan Spark) |
| 2 | **Quitar el fondo** de las fotos | *"El servicio para quitar el fondo aún no está publicado en el servidor"* | Plan Blaze + clave de remove.bg + publicar la Cloud Function | No dentro del cupo gratuito, pero pide tarjeta |
| 3 | Eliminar cuenta | Error al confirmar | Se publica junto con el punto 2 | No |
| 4 | Reglas de Firestore y Storage | Algunas pantallas pueden no cargar en producción | Publicar las reglas nuevas | No |
| 5 | App Check y APK firmado | — | Ver `docs/despliegue.md`, secciones 4 y 6 | No |

Todo lo demás (registro e inicio de sesión, armario, cámara y galería, outfits, calendario, colecciones, estadísticas, perfil, modo claro/oscuro) ya funciona.

---

## Paso 0: conseguir acceso al proyecto `ses-wear`

Los puntos 1 a 4 se hacen en la consola de Firebase con una cuenta de Google que tenga permisos en el proyecto. Si al abrir <https://console.firebase.google.com> no aparece **ses-wear** (sale *"Crear un proyecto"*), esa cuenta no tiene acceso.

1. Quien creó el proyecto entra a Firebase Console → `ses-wear` → ⚙️ **Configuración del proyecto** → **Usuarios y permisos** → **Agregar miembro**.
2. Agrega el correo de quien va a configurar, con rol **Propietario** (o **Editor**).
3. Esa persona acepta la invitación y ya ve el proyecto.

> No crear un proyecto nuevo: la app está conectada a `ses-wear` (`lib/firebase_options.dart`, `.firebaserc`). Un proyecto nuevo obligaría a reconfigurar todo.

---

## 1. Chat con la IA (y las demás funciones de IA)

### Qué pasa hoy

Al escribirle al asistente, al identificar una prenda con la cámara o al pedir "Ideas con IA", la app muestra:

> *La IA todavía no está activada en Firebase (AI Logic). Pídele al equipo que la active.*

La conversación guardada en la cuenta demo sí se ve porque está en la base de datos, pero las preguntas nuevas no reciben respuesta.

### Por qué

La app habla con Gemini (la IA de Google) a través de **Firebase AI Logic**, directamente desde el teléfono. No hace falta servidor ni pegar una API key en la app: Firebase la gestiona. Pero el servicio tiene que activarse **una vez** en el proyecto. Mientras no esté activado, Google rechaza las llamadas (error `403 SERVICE_DISABLED`) y la app muestra el mensaje de arriba.

### Qué hay que hacer

1. Firebase Console → proyecto **ses-wear** → menú **Compilación / Build** → **AI Logic** → **Comenzar**.
2. Elegir el proveedor **Gemini Developer API** (no *Vertex AI*, que pide plan Blaze) y confirmar. Firebase crea la clave y la guarda; no hay que copiarla en ningún lado.
3. **Muy recomendado:** en AI Logic → *Configuración*, poner un **límite de solicitudes por usuario** (por ejemplo 20 por minuto). La app llama a la IA desde el teléfono, así que este límite es lo que evita que un solo usuario agote el cupo gratuito de todos.
4. Esperar 1 o 2 minutos a que se propague y probar.

### Cómo comprobar que quedó

- Abrir la app (sirve también la cuenta demo, porque la IA siempre usa el proyecto real): `powershell -ExecutionPolicy Bypass -File scripts\demo\iniciar-demo.ps1`
- Ir al asistente y preguntar *"¿Qué me pongo para la U?"*. Debe responder recomendando prendas del armario.
- Tomar o subir una foto de una prenda: el formulario debe llenarse solo (nombre, tipo, color, tela…).

### Si sigue fallando

| Mensaje en la app | Causa | Solución |
|---|---|---|
| *La IA todavía no está activada…* | AI Logic sin activar o todavía propagándose | Repetir el paso 1–2 y esperar unos minutos |
| *Se acabó el cupo gratuito de la IA por ahora…* | Se llegó al límite por minuto o por día del plan gratuito de Gemini | Esperar; la app ya prueba sola un segundo modelo (`gemini-flash-lite-latest`) |
| *La configuración de la IA en Firebase no es válida* | La clave web de Firebase está restringida | Google Cloud Console → Credenciales → permitir la *Firebase AI Logic API* en la clave del navegador/Android |
| *La IA no está disponible en tu ubicación* | País no soportado por Gemini Developer API | — |

### Dónde está en el código

- `lib/core/ia/servicio_ia.dart`: conexión con Gemini, modelos (`gemini-flash-latest` y de respaldo `gemini-flash-lite-latest`) y mensajes de error.
- `lib/features/assistant/logic/asistente_ia.dart`: instrucciones del asistente de moda y el armario que se le envía.
- `lib/features/wardrobe/logic/identificador_ia.dart`: identificar una prenda a partir de la foto.
- `lib/features/outfits/logic/outfits_ia.dart`: "Ideas con IA".

No hay que tocar código para activarla.

---

## 2. Quitar el fondo de las fotos

### Qué pasa hoy

Al tomar o escoger una foto, la app intenta quitarle el fondo automáticamente y muestra:

> *El servicio para quitar el fondo aún no está publicado en el servidor.*

La prenda se puede guardar igual, con la foto original.

### Por qué

El fondo lo quita **remove.bg**, un servicio externo que necesita una API key. Esa clave **no puede ir dentro de la app** (cualquiera podría sacarla del APK y gastar el cupo), así que la llamada la hace una **Cloud Function** (`quitarFondo`, en `functions/index.js`) que guarda la clave en el gestor de secretos de Firebase. Esa función está programada y probada, pero **nunca se ha publicado** en Firebase, y para publicar Cloud Functions Firebase exige el **plan Blaze**.

### Qué hay que hacer

1. **Pasar el proyecto a Blaze.** Firebase Console → `ses-wear` → abajo a la izquierda *Spark* → **Actualizar** → **Blaze**, y vincular una cuenta de facturación (pide tarjeta).
   - Con el uso de este proyecto no se paga nada: Blaze incluye el mismo nivel gratuito que Spark.
   - Para estar tranquilos, crear una **alerta de presupuesto** de 1 USD en Google Cloud → *Facturación* → *Presupuestos y alertas*.
2. **Crear la clave de remove.bg.** Registrarse en <https://www.remove.bg> → <https://www.remove.bg/dashboard#api-key> → *New API key*. El plan gratis da **50 fotos al mes**.
3. **Instalar lo necesario en el PC** (si no está): Node.js 22 y Firebase CLI (`npm install -g firebase-tools`).
4. **Correr el script de configuración** desde la carpeta `SES-Wear`:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\configurar-claves.ps1
   ```

   El script:
   - crea `functions\.secret.local` y abre el Bloc de notas: pegar la clave en `REMOVE_BG_API_KEY=` y guardar (la línea `GEMINI_API_KEY` se puede dejar como está, la app no la usa);
   - pide iniciar sesión en Firebase (`firebase login`) con la cuenta del Paso 0;
   - sube la clave a Secret Manager;
   - instala dependencias y publica reglas, índices y las funciones `quitarFondo` y `eliminarCuenta`.

   En Mac/Linux: `bash scripts/configurar-claves.sh`.

### Cómo comprobar que quedó

- `firebase functions:list` debe mostrar `quitarFondo` y `eliminarCuenta`.
- En la app: **Cámara** → tomar o escoger una foto de una prenda → en unos segundos debe aparecer la prenda con fondo transparente. El botón **"Usar foto original"** deshace el cambio.

### Probarlo antes de pagar Blaze (solo en el PC)

El emulador de Cloud Functions lee la clave de `functions/.secret.local`, así que se puede probar sin Blaze ni publicar nada:

```powershell
firebase emulators:start --only auth,firestore,storage,functions --project ses-wear
# en otra terminal:
node scripts\demo\sembrar-demo.mjs
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

(El script `scripts\demo\iniciar-demo.ps1` no levanta el emulador de funciones; para incluirlo, agregar `,functions` en la línea que dice `--only auth,firestore,storage`.)

### Límites a tener en cuenta

- **50 fotos al mes para toda la app** (no por usuario), en tamaño *preview* (hasta 0,25 megapíxeles, suficiente para la miniatura).
- Cada usuario puede quitar el fondo **5 veces al día** (`functions/src/limites.js`), para que nadie gaste todo el cupo.
- Formatos aceptados: JPG, PNG y WEBP.

### ⚠️ Riesgo: remove.bg cambia el 1 de diciembre de 2026

remove.bg anunció que su servicio pasa a **Leonardo.Ai** desde el **1 de diciembre de 2026**. Antes de pagar Blaze, conviene revisar en <https://www.remove.bg/api> si la API y el plan gratuito siguen igual. Si dejan de funcionar:

- La app no se rompe: muestra el aviso y guarda la foto original.
- Para cambiar de proveedor solo hay que reescribir `functions/src/fondo.js` (la función recibe la imagen en base64 y devuelve un PNG). Alternativas:
  - otro servicio con API de quitar fondo (por ejemplo Photoroom o Clipdrop), con el mismo esquema de clave en Secret Manager;
  - **ML Kit Subject Segmentation** de Google, que corre en el teléfono, es gratis y no necesita servidor ni Blaze, pero solo funciona en Android (paquete `google_mlkit_subject_segmentation`).

---

## 3. Eliminar cuenta

Perfil → **Eliminar cuenta** llama a la Cloud Function `eliminarCuenta`, que borra el usuario y todos sus datos de Firestore, Storage y Authentication (Ley 1581 de protección de datos). Se publica con el mismo script del punto 2; no necesita clave.

**Comprobar:** con una cuenta de prueba, eliminarla y revisar en la consola que no quedó nada en Firestore, Storage ni Authentication.

---

## 4. Publicar las reglas de Firestore y Storage

Las reglas (`firestore.rules`, `storage.rules`) se actualizaron: validan los datos de cada colección y agregan las nuevas (`planificador`, `colecciones`, `conversaciones`, `uso`). Si en producción siguen las reglas viejas, algunas pantallas pueden quedarse cargando o fallar al guardar.

- Si se hace el punto 2, el script ya las publica.
- Si todavía no se quiere Blaze, se pueden publicar solas (funciona en Spark):

  ```powershell
  firebase login
  firebase deploy --only firestore:rules,firestore:indexes,storage --project ses-wear
  ```

**Pendiente de revisar:** al abrir la app contra el proyecto real (sin `USAR_EMULADORES`), la sesión se quedó cargando. No se pudo confirmar la causa porque no hubo acceso a la consola. Después de publicar las reglas, volver a probar; si sigue pasando, abrir la consola del navegador (F12) y buscar errores `permission-denied`.

---

## 5. Otros pasos antes de la entrega

Están detallados en [`docs/despliegue.md`](despliegue.md):

- **App Check** (sección 4): registrar la app Android con Play Integrity para que solo la app oficial pueda usar Firebase y los cupos de IA. Hacerlo después de que todo lo anterior funcione.
- **APK firmado** (sección 6): `flutter build apk --release` con la llave de release, y agregar sus huellas SHA-1 y SHA-256 en Firebase.

---

## Lista de verificación final

- [ ] Acceso al proyecto `ses-wear` con rol Propietario o Editor
- [ ] AI Logic activado con **Gemini Developer API**
- [ ] Límite de solicitudes por usuario configurado en AI Logic
- [ ] El asistente responde y la identificación de prendas llena el formulario
- [ ] Proyecto en plan Blaze, con alerta de presupuesto
- [ ] Clave de remove.bg en `functions/.secret.local` (y revisado el cambio a Leonardo.Ai)
- [ ] `scripts\configurar-claves.ps1` ejecutado sin errores
- [ ] `firebase functions:list` muestra `quitarFondo` y `eliminarCuenta`
- [ ] Una foto nueva queda sin fondo
- [ ] Eliminar cuenta borra todo
- [ ] La app abre bien contra el proyecto real (sin emuladores)
- [ ] App Check registrado y APK release firmado
