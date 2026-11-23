# SES Wear

> **Tu estilo, más inteligente.**

SES Wear es una aplicación móvil que funciona como asistente inteligente de estilo personal: digitaliza el armario del usuario escaneando sus prendas con la cámara, genera combinaciones (outfits) según la ocasión y el clima, ofrece un asistente conversacional de moda con IA y muestra estadísticas de uso para promover un consumo más responsable.

Proyecto académico — Universidad Militar Nueva Granada, MUL B, 2026.

## Equipo

| Integrante | Rol |
|---|---|
| Santiago Martinez | Arquitectura, interfaz visual y base de datos (Firebase / Firestore) |
| Sofia Salazar Castro | Chatbot e inteligencia artificial |
| Edison Moreno | Documentación |

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Dart) — Android 8.0+ / iOS 14.0+ |
| Autenticación | Firebase Authentication |
| Base de datos | Cloud Firestore |
| Archivos (fotos de prendas) | Firebase Storage |
| Chatbot, identificación de prendas e ideas de outfits | Gemini con Firebase AI Logic (desde la app, sin servidor propio) |
| Quitar el fondo de las fotos | remove.bg desde Cloud Functions (`functions/src/fondo.js`) |
| Generador de outfits | En el celular (instantáneo) y con Gemini (AI Logic) |

Localización: `es-CO` (ISO 639-1 / ISO 3166-1), preparada para escalar a `es-MX`, `es-AR`, etc.

## Funcionalidades

| Requisito | Qué hace la app | Dónde está |
|---|---|---|
| RF-01 | Registro e inicio de sesión con correo, recuperar contraseña y autorización de datos (Ley 1581). Agregar prendas con la cámara del dispositivo o la galería: la IA (Gemini) llena el formulario y remove.bg quita el fondo automáticamente. | `auth`, `wardrobe` |
| RF-02 | Armario: ver, buscar, filtrar (tipo, color, estación, formalidad), detalle, editar, eliminar y "La usé hoy". | `wardrobe` |
| RF-03 | Generador de outfits por ocasión y clima (instantáneo en el celular o "Ideas con IA"), otras opciones, guardar, favoritos y calificación. | `outfits` |
| RF-04 | Asistente de moda que conoce tu armario e historial de conversaciones. | `assistant` |
| RF-05 | Colecciones de prendas y outfits generados solo con ellas. | `collections` |
| RF-06 | Estadísticas: más usadas, en desuso, costo por uso y paleta de colores. | `stats` |
| RF-07 | Calendario para planear outfits; el de hoy aparece en Inicio. | `planner` |
| Perfil | Editar datos y preferencias, modo claro/oscuro, eliminar la cuenta con todos sus datos. | `profile` |

## Estructura del repositorio

```
SES-Wear/
├── lib/                      # Código fuente de la app Flutter
│   ├── main.dart             # Firebase, App Check, tema y navegación principal
│   ├── core/                 # Tema (claro/oscuro), sesión, widgets y utilidades compartidas
│   └── features/             # Un módulo por funcionalidad (data/ models/ screens/ widgets/)
│       ├── home/  auth/  wardrobe/  outfits/  assistant/
│       └── collections/  stats/  planner/  profile/
├── functions/                # Cloud Functions para quitar fondo y eliminar cuenta
│   ├── src/                  # Lógica del servidor y límites de uso
│   └── test/                 # Pruebas de la lógica del servidor (npm test)
├── test/                     # Pruebas de la app (flutter test)
├── test-firebase/            # Pruebas de reglas y funciones con los emuladores
├── docs/                     # Documentación (requisitos, arquitectura, BD, despliegue…)
├── firebase.json             # Configuración de Firebase CLI
├── firebase.pruebas.json     # Emuladores para test-firebase (otros puertos)
├── firestore.rules           # Reglas de Firestore (validan los datos de cada colección)
└── storage.rules             # Reglas de Storage
```

## Cómo funciona la IA y el asistente

```
App Flutter (pestaña Asistente)
   │ AsistenteRepositorio: lee el perfil y las prendas de Firestore
   ▼
ServicioIA → Firebase AI Logic (Gemini Developer API)
   │
   ├── GEMINI_API_KEY configurada: llamada directa a Gemini
   └── Sin clave: Firebase AI Logic gestiona el acceso

AsistenteRepositorio → guarda preguntas y respuestas en Firestore
```

El asistente recomienda combinaciones usando el armario del usuario y conserva el historial en `users/{uid}/conversaciones`. La identificación de prendas y las ideas de outfits también usan Gemini. Las claves locales son opcionales; si se incluyen en la app, quedan embebidas en el binario, así que para producción se recomienda Firebase AI Logic y Cloud Functions con secretos en el servidor.

## Cómo empezar

### Requisitos previos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) y [Git](https://git-scm.com/) en el PATH
- [Node.js](https://nodejs.org/) 22 y Firebase CLI: `npm install -g firebase-tools`
- Java 21 (solo para los emuladores) y Android Studio (para compilar en Android)

### Ejecutar la app

Para usar las claves locales opcionales, crea `claves.json` a partir de la plantilla y agrega allí tus claves. El archivo está excluido de Git:

```powershell
Copy-Item claves.example.json claves.json
```

En VS Code, selecciona **SES Wear** y pulsa F5. Desde la terminal:

```bash
git clone https://github.com/sxntiagofr/SES-Wear.git
cd SES-Wear
flutter pub get
flutter run --dart-define-from-file=claves.json
flutter run --dart-define=USAR_EMULADORES=true --dart-define-from-file=claves.json
```

`GEMINI_API_KEY` usa Gemini directamente; si se deja vacía, la app usa Firebase AI Logic. `REMOVE_BG_API_KEY` llama directamente a remove.bg; si se deja vacía, se usa la Cloud Function `quitarFondo`. Las claves pasadas al compilar pueden extraerse de la app: úsalas solo para desarrollo y no las compartas ni las subas al repositorio. Consulta [`docs/despliegue.md`](docs/despliegue.md).

### Compilar

```bash
flutter build web --release
flutter build apk --release
```

La compilación Android requiere Android Studio y el Android SDK configurado.

### Poner en marcha el backend y los inicios de sesión

Paso a paso en [`docs/despliegue.md`](docs/despliegue.md): claves de API, despliegue de reglas y funciones, Google/Facebook, App Check y la lista de verificación antes de una entrega.

### Pruebas

```bash
flutter analyze && flutter test
cd functions && npm test
cd test-firebase && npm install && npm test   # necesita Java
```

Para probar el chat sin Firebase, en el navegador, ver [`functions/README.md`](functions/README.md).

**Cupos gratuitos** (mensajes del chat, fotos identificadas y fotos sin fondo) y hasta cuándo funcionan: ver [`docs/limites-gratuitos.md`](docs/limites-gratuitos.md). Además, cada usuario tiene un límite diario de usos de IA (`functions/src/limites.js`).

## Flujo de trabajo

- `main`: versión estable para las entregas.
- Cada integrante trabaja en su propia rama (`feature/...` o `docs/...`) y abre un pull request.

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para la división del trabajo, el paso a paso con GitHub Desktop y el formato de los commits.

## Metodología

Proceso Unificado (RUP): Inicio → Elaboración → Construcción (3 iteraciones) → Transición.

| Iteración | Alcance |
|---|---|
| 1 | Registro de usuarios, autenticación y armario digital |
| 2 | Generador automático de outfits |
| 3 | Asistente conversacional de IA (chatbot) |
