# `functions/`: backend del asistente de IA

Responsable: Sofia Salazar Castro · Rama: `feature/chatbot`

Prueba del chatbot de moda de SES Wear (RF-04). Ya mantiene una conversación normal y está escrito para reutilizarse tal cual cuando exista la app Flutter.

También recibe **fotos de prendas**: el usuario toma una foto (o la elige de la galería), pregunta por una ocasión y el asistente identifica la prenda, dice si sirve (**Sí sirve** / **No es la mejor opción** / **Depende**) y propone con qué combinarla.

| Archivo | Qué hace |
|---|---|
| `src/asistente.js` | Lógica del asistente: instrucciones, validación del historial y llamada a la API. No depende de Firebase. |
| `index.js` | Cloud Function `chat` que llama la app Flutter. Usa `src/asistente.js` y `src/datos.js`. |
| `src/identificador.js` | Identificación de prendas desde una foto (Cloud Function `identificarPrenda`). |
| `src/fondo.js` | Quitar el fondo de la foto con remove.bg (Cloud Function `quitarFondo`). |
| `src/outfits.js` | Generador de outfits con IA (Cloud Function `generarOutfits`, RF-03). |
| `src/limites.js` | Límite de usos diarios de IA por usuario (`users/{uid}/uso/{fecha}`). |
| `src/cuenta.js` | Borrado completo de la cuenta (Cloud Function `eliminarCuenta`, Ley 1581). |
| `test/` | Pruebas de la lógica (`npm test`, sin internet). |
| `src/datos.js` | Conexión con Firestore: lee el perfil y las prendas del usuario y guarda el historial de conversaciones. |
| `servidor-prueba.js` | Servidor local para probar el chat en el navegador, sin Firebase. |
| `prueba/index.html` | Interfaz de prueba del chat, con la estética de la app. |
| `.secret.local.example` | Plantilla del archivo donde va la API key. |

## API de IA

Usa la API de **Gemini (Google)** con el SDK oficial [`@google/genai`](https://www.npmjs.com/package/@google/genai). Gemini tiene un nivel gratuito, suficiente para pruebas.

- Modelo principal: `gemini-3.5-flash`.
- Si está saturado o se alcanzó su límite gratuito, el asistente cambia automáticamente a `gemini-flash-lite-latest`.
- Se puede forzar un solo modelo con la variable `CHATBOT_MODEL` en `.secret.local`.

La API key es **privada**:

- **En tu PC** va en `functions/.secret.local`. El `.gitignore` excluye ese archivo, así que nunca se sube a GitHub.
- **En Firebase** va en Secret Manager (`firebase functions:secrets:set GEMINI_API_KEY`). La función la lee en tiempo de ejecución.
- **Nunca** va dentro de la app Flutter: la app llama a la Cloud Function, y es la función la que habla con la API.

## Probar el chat en tu PC

Requisitos: [Node.js](https://nodejs.org/) 22 o superior.

1. Crea una API key gratuita en [Google AI Studio](https://aistudio.google.com/apikey).
2. En la carpeta `functions/`, copia `.secret.local.example` como `.secret.local`.
3. Abre `.secret.local` y pega tu key después de `GEMINI_API_KEY=`.
4. Instala las dependencias y arranca el servidor:

   ```bash
   cd functions
   npm install
   npm run prueba
   ```

5. Abre http://localhost:3000 y escribe. Con el botón de cámara puedes tomar una foto con la webcam o elegir una imagen de la galería.

Para probarlo desde el celular hace falta HTTPS (los navegadores solo dan acceso a la cámara en `localhost` o en sitios seguros). En la app Flutter esto no aplica, porque la foto se toma con el paquete [`image_picker`](https://pub.dev/packages/image_picker).

## Desplegar en Firebase (cuando el proyecto esté creado)

Requiere el plan **Blaze** de Firebase (las Cloud Functions que llaman APIs externas no funcionan en el plan gratuito Spark).

```bash
npm install -g firebase-tools
firebase login
firebase use --add                              # elegir el proyecto de SES Wear
firebase functions:secrets:set GEMINI_API_KEY    # pegar la key cuando la pida
firebase deploy --only functions
```

## Cómo lo usará la app Flutter

Con el paquete [`cloud_functions`](https://pub.dev/packages/cloud_functions). El usuario debe haber iniciado sesión con Firebase Authentication; si no, la función responde `unauthenticated`.

```dart
final resultado = await FirebaseFunctions.instance
    .httpsCallable('chat')
    .call({
      'mensajes': [
        {'rol': 'usuario', 'texto': 'Hola, ¿qué me pongo hoy para la U?'},
        // ... el resto del historial: {'rol': 'asistente', 'texto': '...'}
      ],
    });

final respuesta = resultado.data['texto'] as String;
```

Para enviar una foto, se reduce a máximo ~1024 px y se manda en base64 junto al texto:

```dart
final foto = await ImagePicker().pickImage(
  source: ImageSource.camera,
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85,
);
if (foto != null) {
  final datos = base64Encode(await foto.readAsBytes());
  mensajes.add({
    'rol': 'usuario',
    'texto': '¿Me sirve para una boda de día?',
    'imagen': {'tipo': 'image/jpeg', 'datos': datos},
  });
}
```

### Contrato de la función `chat`

**Entrada** (`data`):

```json
{
  "mensajes": [
    { "rol": "usuario", "texto": "Hola" },
    { "rol": "asistente", "texto": "¡Hola! ¿En qué te ayudo?" },
    { "rol": "usuario", "texto": "¿Qué combina con un jean azul?" }
  ]
}
```

- `rol`: `"usuario"` o `"asistente"`.
- El último mensaje debe ser del usuario.
- Se toman los últimos 40 mensajes, de máximo 4000 caracteres cada uno.
- `imagen` (opcional, solo en mensajes del usuario): `{ "tipo": "image/jpeg", "datos": "<base64>" }`. Tipos: JPG, PNG, WEBP o HEIC; máximo 4 MB.
- Si un mensaje trae foto y no trae texto, se pregunta por defecto para qué ocasiones sirve la prenda.
- Para ahorrar cuota, solo se reenvían a Gemini las 3 fotos más recientes del historial; las anteriores se reemplazan por una nota.

**Salida**:

```json
{ "texto": "Un jean azul combina con casi todo…", "rechazado": false, "conversacionId": "abc123" }
```

`rechazado: true` significa que los filtros de seguridad de Gemini bloquearon la pregunta. En ese caso `texto` trae un mensaje amable para mostrar.

## Identificación de prendas (`identificarPrenda`)

Cloud Function aparte del chat, que usa la pantalla **Agregar prenda** del armario (`lib/features/wardrobe`). Lógica en `src/identificador.js`; usa los mismos modelos de Gemini y la misma API key que el asistente.

**Entrada** (`data`): `{ "imagen": { "tipo": "image/jpeg", "datos": "<base64>" } }` (JPG, PNG, WEBP o HEIC; máximo 4 MB).

**Salida** (Gemini responde con un esquema JSON fijo):

```json
{
  "esPrenda": true,
  "nombre": "Jean azul clásico",
  "tipo": "inferior",
  "categoria": "jean",
  "colorPrimario": "azul",
  "colorSecundario": "",
  "tela": "denim",
  "estilo": "clásico",
  "formalidad": "casual",
  "estacion": "todo el año",
  "etiquetas": ["tiro alto", "bota recta"]
}
```

- `tipo`: `superior`, `inferior`, `calzado`, `accesorio`, `enterizo` o `abrigo`.
- `formalidad`: `casual`, `deportivo`, `semiformal`, `formal` o `fiesta`.
- `estacion`: `calor`, `frío`, `lluvia` o `todo el año`.
- `esPrenda: false` si la foto no muestra ropa, calzado ni accesorios.

Para probarla en tu PC sin Firebase: `npm run prueba` y envía un `POST` a `http://localhost:3000/api/identificar` con el mismo JSON de entrada.

## Quitar el fondo (`quitarFondo`)

Cloud Function que usa la API de **remove.bg** (`src/fondo.js`). La app la llama solo cuando el usuario toca **"Quitar fondo"** en "Agregar prenda".

- **Entrada**: `{ "imagen": { "tipo": "image/jpeg", "datos": "<base64>" } }` (JPG, PNG o WEBP).
- **Salida**: `{ "imagen": { "tipo": "image/png", "datos": "<base64>" }, "creditosUsados": 0.25, "fotosGratisRestantes": 41 }`.
- API key en Secret Manager: `firebase functions:secrets:set REMOVE_BG_API_KEY` (en tu PC, en `.secret.local`).
- Plan gratuito: **50 fotos al mes** para toda la app, en tamaño *preview* (hasta 0,25 MP).
- Prueba local: `POST http://localhost:3000/api/quitar-fondo`.
- remove.bg anunció que el 1 de diciembre de 2026 pasa a Leonardo.Ai. Si la API deja de funcionar, la app avisa y guarda la foto original.

Cupos y fechas de todos los servicios gratuitos: [`docs/limites-gratuitos.md`](../docs/limites-gratuitos.md).

### Conexión con la base de datos

En cada mensaje, la función `chat`:

1. Lee de Firestore el perfil (`users/{uid}`: nombre, ciudad, preferencias) y hasta 150 prendas de `users/{uid}/prendas`, y se los pasa a Gemini como contexto. Así el asistente recomienda con lo que el usuario ya tiene.
2. Guarda la pregunta y la respuesta en `users/{uid}/conversaciones/{conversacionId}/mensajes` (las fotos no se guardan, solo `tieneFoto: true`).
3. Devuelve el `conversacionId`. La app lo envía en el siguiente mensaje (`data.conversacionId`) para seguir en la misma conversación; si no lo envía, se crea una nueva.

Si Firestore falla, el asistente responde igual (sin armario) y el error queda en los logs.

El servidor de prueba local (`npm run prueba`) no usa Firestore: responde sin armario.

## Generar outfits (`generarOutfits`)

`call({ ocasion, clima, cantidad?, excluir?: [[ids]], coleccionId? })` → `{ outfits: [{ nombre, prendaIds, explicacion }] }`. Lee las prendas del usuario en Firestore (o solo las de una colección) y Gemini solo puede usar ids que existen. `excluir` sirve para "otras opciones" sin repetir.

## Eliminar la cuenta (`eliminarCuenta`)

`call({ confirmacion: "ELIMINAR" })` borra `users/{uid}` con todas sus subcolecciones, las fotos en Storage y la cuenta de Authentication.

## Límite diario y App Check

Cada usuario tiene un cupo diario por función (`src/limites.js`: chat 100, identificarPrenda 40, generarOutfits 30, quitarFondo 5). Si se pasa, la función responde `resource-exhausted`. Con `EXIGIR_APP_CHECK=true` en `functions/.env` solo se aceptan llamadas de la app oficial (ver `docs/despliegue.md`).

## Pendiente

- Clima de la ciudad del usuario (hoy el usuario elige el clima en el generador).
