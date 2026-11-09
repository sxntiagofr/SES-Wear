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
| Chatbot de moda | Gemini (Google) desde Cloud Functions (`functions/`) |
| IA de visión (identificación de prendas) | _por definir_ |

Localización: `es-CO` (ISO 639-1 / ISO 3166-1), preparada para escalar a `es-MX`, `es-AR`, etc.

## Estructura del repositorio

```
SES-Wear/
├── lib/                      # Código fuente de la app Flutter
│   ├── main.dart             # Inicializa Firebase y la navegación principal
│   ├── firebase_options.dart # Generado por FlutterFire
│   ├── core/theme/           # Tema visual (AppTheme)
│   └── features/             # Un módulo por funcionalidad
│       ├── home/             # Pantalla de inicio
│       ├── auth/             # Registro, inicio de sesión, recuperar contraseña (RF-01)
│       ├── wardrobe/         # Armario virtual: CRUD de prendas y filtros (RF-01, RF-02)
│       ├── outfits/          # Generador inteligente de outfits (RF-03)
│       ├── assistant/        # Chatbot de moda con IA (RF-04)
│       ├── collections/      # Etiquetas y colecciones personalizadas (RF-05)
│       ├── stats/            # Estadísticas y consumo responsable (RF-06)
│       ├── planner/          # Calendario de atuendos (RF-07)
│       └── profile/          # Perfil del usuario
├── functions/                # Backend del asistente de IA (Cloud Functions + Gemini)
├── test/                     # Pruebas unitarias y de widgets
├── docs/                     # Documentación del proyecto
│   ├── requisitos.md         # Requerimientos funcionales y no funcionales
│   ├── arquitectura.md       # Arquitectura y modelo de datos en Firestore
│   └── entregas/             # Documentos entregados por corte
├── android/ ios/ web/ ...    # Carpetas de plataforma de Flutter
├── firebase.json             # Configuración de Firebase CLI (FlutterFire, reglas, funciones, emuladores)
├── .firebaserc               # Proyecto de Firebase por defecto (ses-wear)
├── firestore.rules           # Reglas de seguridad de Firestore
├── firestore.indexes.json    # Índices de Firestore
└── storage.rules             # Reglas de seguridad de Firebase Storage
```

## Cómo funciona el asistente con la base de datos

```
App Flutter (pestaña Asistente)
   │  FirebaseFunctions.httpsCallable('chat')  { mensajes, conversacionId }
   ▼
Cloud Function `chat` (functions/index.js)
   │ 1. Lee de Firestore el perfil (users/{uid}) y las prendas (users/{uid}/prendas)
   │ 2. Se las pasa a Gemini como contexto junto con la conversación
   │ 3. Guarda la pregunta y la respuesta en users/{uid}/conversaciones/{id}/mensajes
   ▼
App ← { texto, rechazado, conversacionId }  (al abrir el chat se carga el historial desde Firestore)
```

Así, el asistente recomienda combinaciones con las prendas que el usuario ya registró en su armario. La API key de Gemini vive solo en el servidor (Secret Manager); nunca en la app.

## Cómo empezar

### Requisitos previos

- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (incluye Dart)
- [Node.js](https://nodejs.org/) 22 y Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### Ejecutar la app

```bash
git clone https://github.com/sxntiagofr/SES-Wear.git
cd SES-Wear
flutter pub get
flutter run
```

### Poner en marcha el asistente (una sola vez)

1. En Firebase Console → **Authentication → Método de acceso**, activa **Anónimo** (mientras no exista la pantalla de inicio de sesión, la app entra de forma anónima para poder usar el asistente).
2. El proyecto debe estar en el plan **Blaze** (las Cloud Functions que llaman APIs externas no funcionan en el plan Spark).
3. Despliega reglas y funciones:

```bash
firebase login
firebase functions:secrets:set GEMINI_API_KEY   # pegar la API key de Google AI Studio
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Para probar el chat sin Firebase, en el navegador, ver [`functions/README.md`](functions/README.md).

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
