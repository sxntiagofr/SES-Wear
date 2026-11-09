# Módulo `wardrobe`: armario virtual

Cubre **RF-01 (registro e identificación automática por IA)** y la base de **RF-02 (gestión del armario)**.

## Cómo funciona "Agregar prenda"

```
Pestaña Armario → botón "Agregar prenda" → Tomar foto / Elegir de la galería (image_picker, ~1024 px)
   │
   ▼
Cloud Function `identificarPrenda` (functions/src/identificador.js)
   │  Gemini analiza la foto y responde en JSON:
   │  nombre, tipo, categoria, colorPrimario, colorSecundario, tela, estilo,
   │  formalidad, estacion, etiquetas
   ▼
Pantalla "Nueva prenda": el formulario aparece lleno; el usuario revisa y corrige
   │  Guardar
   ▼
Storage:   users/{uid}/prendas/{prendaId}.jpg
Firestore: users/{uid}/prendas/{prendaId}   (fotoUrl, identificadaPorIA: true, fechaCreacion…)
```

Las prendas guardadas aparecen en la cuadrícula del armario en tiempo real y el **asistente de IA las usa como contexto** para recomendar combinaciones. Mantener presionada una prenda permite eliminarla.

Si la IA falla o la foto no muestra ropa, la pantalla lo avisa y el usuario puede llenar los datos a mano.

## Archivos

| Archivo | Qué hace |
|---|---|
| `models/prenda.dart` | Modelo `Prenda` y opciones cerradas (tipos, formalidades, estaciones) |
| `data/prendas_repositorio.dart` | Llama a la IA, sube la foto a Storage y guarda/lee/elimina en Firestore |
| `screens/armario_screen.dart` | Cuadrícula del armario y botón "Agregar prenda" |
| `screens/nueva_prenda_screen.dart` | Foto + formulario llenado por la IA |
| `widgets/tarjeta_prenda.dart` | Tarjeta de cada prenda |

## Pendiente

- [ ] Quitar el fondo de la foto (falta elegir servicio: p. ej. remove.bg, o un modelo de Gemini que edite imágenes, que no tiene nivel gratuito).
- [ ] Editar una prenda ya guardada.
- [ ] Filtros por color, estación, formalidad y tipo (RF-02).
