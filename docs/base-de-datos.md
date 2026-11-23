# Base de datos (Cloud Firestore + Cloud Storage)

Proyecto Firebase: **ses-wear** — <https://console.firebase.google.com/project/ses-wear/firestore>

Todos los datos de un usuario cuelgan de su documento `users/{uid}`, donde `{uid}` es el identificador que le da Firebase Authentication al crear la cuenta. Así los armarios quedan separados y las reglas (`firestore.rules`) solo dejan a cada usuario leer y escribir lo suyo.

```
users/{uid}                                   ← perfil (se crea al registrarse)
├── prendas/{prendaId}                        ← armario (RF-01, RF-02)
├── conversaciones/{conversacionId}           ← asistente (RF-04)
│   └── mensajes/{mensajeId}
├── outfits/{outfitId}                        ← outfits guardados (RF-03)
├── planificador/{AAAA-MM-DD}                 ← calendario (RF-07)
├── colecciones/{id}                          ← colecciones de prendas (RF-05)
├── uso/{AAAA-MM-DD}                          ← cupo diario de IA (solo lo escribe el servidor)
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
Lo escribe `lib/features/wardrobe/data/prendas_repositorio.dart`: `nombre`, `tipo`, `categoria`, `colorPrimario`, `colorSecundario`, `tela`, `estilo`, `formalidad`, `estacion`, `etiquetas[]`, `fotoUrl`, `vecesUsada`, `identificadaPorIA`, `precio` (pesos, opcional), `ultimoUso` (timestamp) y `fechaCreacion`.

"La usé hoy" suma 1 a `vecesUsada` y actualiza `ultimoUso` (alimentan las estadísticas, RF-06). Las reglas validan los tipos y los valores de `tipo`, `formalidad` y `estacion`.

## `users/{uid}/outfits/{outfitId}` (RF-03)
Lo escribe `lib/features/outfits/data/outfits_repositorio.dart`: `nombre`, `prendaIds[]`, `ocasion`, `clima`, `explicacion`, `favorito`, `calificacion` (0 a 5), `origen` (`local`, `ia` o `manual`), `fechaCreacion`.

## `users/{uid}/colecciones/{id}` (RF-05)
`nombre`, `descripcion`, `prendaIds[]`, `fechaCreacion`. El generador de outfits puede usar solo las prendas de una colección.

## `users/{uid}/planificador/{AAAA-MM-DD}` (RF-07)
El id del documento es la fecha. Campos: `fecha` (igual al id), `outfitId`, `outfitNombre`, `prendaIds[]` (copia, por si se borra el outfit), `nota`, `actualizado`.

## `users/{uid}/uso/{AAAA-MM-DD}`
Contador de usos diarios de las funciones de IA por usuario (`chat`, `identificarPrenda`, `generarOutfits`, `quitarFondo`), en hora de Colombia. Lo escribe solo el servidor (`functions/src/limites.js`); la app puede leerlo.

## `users/{uid}/conversaciones/{id}` y `mensajes/{id}`
Los escribe `AsistenteRepositorio` desde la app después de recibir respuesta de Gemini. La conversación guarda `titulo`, `fechaCreacion`, `ultimaActividad`; cada mensaje guarda `rol`, `texto`, `fecha` y, para respuestas, `rechazado`. Al abrir el asistente se carga la conversación más reciente.

## Eliminar la cuenta
La Cloud Function `eliminarCuenta` borra `users/{uid}` con todas sus subcolecciones, las fotos de `users/{uid}/` en Storage y la cuenta de Authentication (Ley 1581, derecho de supresión).

## Fotos: Cloud Storage y alternativa Firestore
Cuando Storage está disponible, las fotos se guardan en `users/{uid}/prendas/...`; solo el dueño puede leerlas y se aceptan imágenes de máximo 10 MB (`storage.rules`). Si Storage no está disponible o falla, la app comprime la imagen y la guarda como Data URL (`data:image/...;base64,...`) en `fotoUrl` del documento de la prenda.

## Dónde verlo
- Usuarios registrados: **Authentication → Usuarios**.
- Datos: **Firestore Database → Datos → users**.
- Fotos: **Storage → users**.
