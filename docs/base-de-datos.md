# Base de datos (Cloud Firestore + Cloud Storage)

Proyecto Firebase: **ses-wear** — <https://console.firebase.google.com/project/ses-wear/firestore>

Todos los datos de un usuario cuelgan de su documento `users/{uid}`, donde `{uid}` es el identificador que le da Firebase Authentication al crear la cuenta. Así los armarios quedan separados y las reglas (`firestore.rules`) solo dejan a cada usuario leer y escribir lo suyo.

```
users/{uid}                                   ← perfil (se crea al registrarse)
├── prendas/{prendaId}                        ← armario (RF-01, RF-02)
├── conversaciones/{conversacionId}           ← asistente (RF-04)
│   └── mensajes/{mensajeId}
├── outfits/{outfitId}                        ← generador (RF-03)          · por construir
├── planificador/{AAAA-MM-DD}                 ← calendario (RF-07)         · por construir
├── etiquetas/{id} · colecciones/{id}         ← agrupaciones (RF-05)       · por construir
└── categorias/{id}                           ← categorías propias (RF-05.4) · por construir

categorias/{id}                               ← catálogo global (solo admin escribe) · por construir
parametros/{id}                               ← umbral IA, días de desuso... (solo admin) · por construir
```

## `users/{uid}` — perfil

Lo escribe `lib/features/auth/data/auth_repositorio.dart` (modelo en `models/perfil_usuario.dart`).

| Campo | Tipo | Ejemplo / nota |
|---|---|---|
| `email` | string | `ana@correo.com` (en minúsculas) |
| `nombre` | string | `Ana` |
| `apellido` | string | `Gómez` |
| `telefono` | string | `3001234567` |
| `ciudad` | string | `Bogotá` (para el clima; se llena en Perfil) |
| `fotoUrl` | string? | foto de Google/Facebook |
| `proveedor` | string | `password`, `google.com` o `facebook.com` |
| `rol` | string | siempre `usuario`; `admin` solo lo pone el servidor |
| `locale` | string | `es-CO` |
| `preferencias` | map | `{estilos: [], colores: [], ocasiones: []}` |
| `consentimientoDatos` | map | `{aceptado: true, fecha: timestamp, version: "1.0"}` (Ley 1581) |
| `fechaRegistro` | timestamp | hora del servidor al crear la cuenta |
| `ultimoAcceso` | timestamp | se actualiza en cada inicio de sesión |

La contraseña **no** se guarda en Firestore: la maneja Firebase Authentication.

## `users/{uid}/prendas/{prendaId}`
Lo escribe `lib/features/wardrobe/data/prendas_repositorio.dart`: `nombre`, `tipo`, `categoria`, `colorPrimario`, `colorSecundario`, `tela`, `estilo`, `formalidad`, `estacion`, `etiquetas[]`, `fotoUrl`, `vecesUsada`, `identificadaPorIA`, `fechaCreacion`.

## `users/{uid}/conversaciones/{id}` y `mensajes/{id}`
Los escribe la Cloud Function `chat` (`functions/src/datos.js`): conversación con `titulo`, `fechaCreacion`, `ultimaActividad`; cada mensaje con `rol`, `texto`, `tieneFoto`, `fecha`.

## Cloud Storage
`users/{uid}/prendas/...` — fotos de las prendas. Solo el dueño las lee; solo imágenes de máximo 10 MB (`storage.rules`).

## Dónde verlo
- Usuarios registrados: **Authentication → Usuarios**.
- Datos: **Firestore Database → Datos → users**.
- Fotos: **Storage → users**.
