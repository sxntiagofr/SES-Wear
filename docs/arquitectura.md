# Arquitectura

## Visión general

La aplicación está desarrollada en Flutter y usa Firebase para autenticación, datos y servicios de backend. Cada usuario tiene sus datos bajo `users/{uid}`; las reglas de Firestore y Storage limitan el acceso al propietario.

```
App Flutter
   ├── Firebase Authentication → registro, inicio y recuperación de contraseña
   ├── Cloud Firestore          → perfil, prendas, outfits, colecciones y planificador
   ├── Firebase Storage         → fotos cuando el servicio está disponible
   ├── Firebase AI Logic        → Gemini para chat, identificación e ideas de outfits
   └── Cloud Functions          → quitar fondo (alternativa segura) y eliminar cuenta
```

### Servicios de IA e imágenes

- `ServicioIA` conecta chat, identificación de prendas y outfits con Gemini. Por defecto usa Firebase AI Logic. Si se configura `GEMINI_API_KEY` en `claves.json`, usa Gemini directamente.
- `AsistenteRepositorio` obtiene el perfil y las prendas de Firestore, prepara el contexto para el modelo y guarda preguntas y respuestas en la subcolección de conversaciones.
- El fondo se quita con remove.bg. Con `REMOVE_BG_API_KEY` configurada, la app llama al servicio directamente; sin ella, usa la Cloud Function `quitarFondo`.
- Las claves definidas al compilar la app pueden extraerse de su binario. La opción directa es para desarrollo/pruebas; para producción, guardar claves en el servidor y usar Firebase AI Logic o Cloud Functions.
- Al guardar una prenda, la imagen se sube a Storage. Si Storage no está habilitado o falla, se comprime y guarda como Data URL en el campo `fotoUrl` de Firestore.

La configuración local se describe en [Puesta en marcha y despliegue](despliegue.md); `claves.json` se deriva de `claves.example.json` y está ignorado por Git.

## Modelo de datos en Firestore

```
users/{uid}
  ├── perfil: nombre, apellido, email, teléfono, ciudad, preferencias, consentimiento
  ├── prendas/{prendaId}
  │     nombre, tipo, categoria, colores, tela, estilo, formalidad, estacion,
  │     etiquetas[], precio, vecesUsada, ultimoUso, fotoUrl, identificadaPorIA
  ├── conversaciones/{conversacionId}
  │     titulo, fechaCreacion, ultimaActividad
  │     └── mensajes/{mensajeId}: rol, texto, rechazado, fecha
  ├── outfits/{outfitId}
  │     nombre, prendaIds[], ocasion, clima, explicacion, favorito, calificacion, origen
  ├── colecciones/{coleccionId}
  │     nombre, descripcion, prendaIds[], fechaCreacion
  ├── planificador/{AAAA-MM-DD}
  │     outfitId, outfitNombre, prendaIds[], nota, actualizado
  └── uso/{AAAA-MM-DD}              // contadores gestionados por el servidor
```

El detalle de campos y reglas está en [Base de datos](base-de-datos.md), `firestore.rules` y `storage.rules`.

## Organización del código

- `lib/core/`: configuración, sesión, tema, IA, utilidades y widgets compartidos.
- `lib/features/`: módulos de autenticación, armario, outfits, asistente, colecciones, estadísticas, planificador y perfil.
- `functions/`: endpoints de servidor, incluidos quitar fondo y eliminación de cuenta.
- `test/` y `test-firebase/`: pruebas unitarias, de widgets, reglas y funciones.
