# Módulo `assistant`: chatbot de moda e IA

Responsable: Sofia Salazar Castro · Rama: `feature/chatbot`

Cubre **RF-04 (Asistente conversacional de moda)** y la parte de IA de **RF-01 (identificación automática de prendas)**.

## Alcance

### Chatbot (RF-04)

- Pantalla de conversación con el asistente: lista de mensajes, campo de texto y botón de enviar.
- Respuestas sobre combinaciones, tendencias e ideas de vestuario.
- Asesoría personalizada según la imagen que el usuario quiere proyectar.
- El asistente conoce el armario del usuario (prendas guardadas en Firestore) para recomendar con lo que ya tiene.
- Considera la ocasión y el clima de la ciudad del usuario.
- Habla en español de Colombia (`es-CO`) y entiende el léxico local: saco, buso, jean, chaqueta, tenis, etc.
- Guarda el historial de conversaciones del usuario.

### Identificación de prendas (RF-01, parte de IA)

- A partir de la foto de una prenda, sugerir automáticamente: tipo (superior, inferior, calzado, accesorio), categoría, color primario y secundario, tela o textura y estilo.
- Remoción del fondo de la foto.
- Meta de rendimiento (RNF-01): ≤ 3 s por foto.

## Arquitectura propuesta

```
App Flutter (lib/features/assistant)
   │  envía el mensaje del usuario
   ▼
Servidor (Cloud Function u otro backend)   ← aquí vive la API key de la IA
   │  arma el contexto: perfil, prendas del armario, clima, historial
   ▼
Proveedor de IA: Gemini (Google)
   │
   ▼
Respuesta → se guarda en Firestore → se muestra en la app
```

La API key del proveedor de IA **nunca** va dentro de la app. Debe quedar del lado del servidor.

## Datos en Firestore

Se integran con el modelo que defina Santiago (`feature/arquitectura`):

```
users/{uid}/conversaciones/{conversacionId}
  titulo, fechaCreacion, ultimaActividad

users/{uid}/conversaciones/{conversacionId}/mensajes/{mensajeId}
  rol (usuario | asistente), texto, fecha
```

Las reglas actuales de `firestore.rules` ya cubren estas subcolecciones: cada usuario solo accede a lo suyo.

## Estructura de carpetas prevista

```
lib/features/assistant/
├── data/           # Llamadas al servidor de IA y a Firestore (conversaciones, mensajes)
├── models/         # Mensaje, Conversacion
├── screens/        # Pantalla del chat
└── widgets/        # Burbuja de mensaje, campo de texto, sugerencias rápidas
```

## Depende de

- `feature/arquitectura`: proyecto Flutter creado, conexión con Firebase, autenticación, modelo de prendas y tema visual.
- La pantalla del chat se agrega a la navegación principal de la app (`MainNavigation`).

## Tareas

- [x] Elegir proveedor de IA para el chatbot: Gemini (Google), ver `functions/README.md`
- [x] Chatbot de prueba funcionando (`functions/`)
- [x] Enviar una foto de una prenda y preguntar si sirve para una ocasión
- [ ] Elegir servicio para la identificación de prendas y la remoción de fondo
- [ ] Elegir servicio de clima
- [x] Modelos `Mensaje` y `Conversacion`
- [x] Pantalla del chat con mensajes de prueba (sin IA)
- [x] Servidor que reciba el mensaje y llame al proveedor de IA (Cloud Function `chat`)
- [x] Guardar y cargar el historial desde Firestore
- [x] Incluir las prendas del usuario como contexto del asistente
- [x] Instrucciones del asistente en `es-CO` con léxico colombiano
- [ ] Identificación automática de atributos desde la foto
- [ ] Pruebas
