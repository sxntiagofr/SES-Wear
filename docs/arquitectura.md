# Arquitectura

> Borrador inicial. La arquitectura definitiva en Firebase/Firestore la está diseñando el equipo; actualizar este documento cuando quede definida.

## Visión general

```
App Flutter (lib/features/*)
   │
   ├── Firebase Authentication  → registro, inicio de sesión, recuperar contraseña
   ├── Cloud Firestore          → usuarios, prendas, outfits, colecciones, planificador
   ├── Firebase Storage         → fotos de las prendas
   └── Cloud Functions (`chat`) → asistente de moda con Gemini; lee las prendas y guarda el historial en Firestore
```

Los datos se organizan por usuario para mantener separados los armarios personales. Las reglas de seguridad (`firestore.rules`, `storage.rules`) solo permiten que cada usuario acceda a lo que está bajo su propio `uid`.

## Modelo de datos propuesto (Firestore)

```
users/{uid}
  ├── nombre, correo, fechaRegistro, preferencias, ciudad
  │
  ├── prendas/{prendaId}
  │     nombre, categoria, tipo (superior | inferior | calzado | accesorio),
  │     colorPrimario, colorSecundario, tela, estilo, talla, marca,
  │     estacion, formalidad, precio, vecesUsada, ultimoUso,
  │     fotoUrl, etiquetas[], fechaCreacion, identificadaPorIA
  │
  ├── outfits/{outfitId}
  │     nombre, prendaIds[], ocasion, favorito, calificacion, fechaCreacion
  │
  ├── colecciones/{coleccionId}
  │     nombre, prendaIds[]
  │
  └── planificador/{fecha}          // fecha en formato AAAA-MM-DD
        outfitId, nota
│
└── conversaciones/{conversacionId}      // las escribe la Cloud Function `chat`
      titulo, fechaCreacion, ultimaActividad
      └── mensajes/{mensajeId}
            rol (usuario | asistente), texto, tieneFoto, rechazado, fecha
```

Fotos en Storage: `users/{uid}/prendas/{prendaId}.jpg`

## Organización del código

Cada carpeta de `lib/features/` agrupa todo lo de una funcionalidad (pantallas, widgets, lógica y acceso a datos), de modo que se puedan agregar módulos nuevos sin tocar los existentes. Lo compartido entre módulos (tema, constantes, servicios de Firebase) va en `lib/core/`.

## Pendiente por definir

- [ ] Modelo de datos definitivo en Firestore
- [ ] Servicio de IA para reconocimiento de prendas (Cloud Functions, API externa o backend en Python)
- [x] Proveedor del chatbot: Gemini desde Cloud Functions (`functions/`)
- [ ] Servicio de clima para las recomendaciones
