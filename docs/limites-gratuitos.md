# Límites de los servicios gratuitos

Revisado el 8 de noviembre de 2026. Los proveedores pueden cambiar estos límites sin aviso: confirmarlos antes de cada entrega.

## Resumen

| Función de la app | Servicio | Cupo gratis | Se renueva | Hasta cuándo |
|---|---|---|---|---|
| Mensajes del asistente (chat) | Gemini API | ≈ 520 solicitudes al día **entre chat e identificación de fotos** (ver detalle) | Todos los días a las **3:00 a. m. hora Colombia** (medianoche del Pacífico) | Sin fecha de fin anunciada |
| Identificar prenda desde la foto | Gemini API | El mismo cupo de arriba (cada foto = 1 solicitud) | Igual | Sin fecha de fin anunciada |
| Quitar fondo de la foto | remove.bg | **50 fotos al mes** para toda la app, en tamaño *preview* (hasta 0,25 MP, p. ej. 625 × 400) | Cada mes | **1 de diciembre de 2026** (ver abajo) |

Los cupos son **por proyecto / cuenta**, no por usuario: todos los usuarios de la app comparten el mismo cupo.

## Gemini (chat e identificación de prendas)

La app usa primero `gemini-3.5-flash` y, si se acabó su cupo o está saturado, pasa sola a `gemini-flash-lite-latest` (`functions/src/asistente.js`).

| Modelo | Por minuto | Por día |
|---|---|---|
| Gemini Flash (modelo principal) | ≈ 5 solicitudes | ≈ 20 solicitudes |
| Gemini Flash-Lite (respaldo) | 15 solicitudes | 500 solicitudes |

- Cada mensaje enviado en el chat cuenta como 1 solicitud. Cada foto analizada en "Agregar prenda" también.
- En total son unas **520 solicitudes al día**. Después de las primeras ~20, las respuestas las da Flash-Lite (un poco menos detalladas).
- El cupo diario se renueva a la medianoche hora del Pacífico: **3:00 a. m. en Colombia** (2:00 a. m. entre marzo y noviembre, cuando EE. UU. usa horario de verano).
- Si se llega al límite, la app muestra: *"Se acabó el cupo gratuito de hoy…"* (diario) o *"Espera un minuto…"* (por minuto).
- Los límites exactos del proyecto se ven en [Google AI Studio → Rate limits](https://aistudio.google.com/). Google indica que estos límites no están garantizados.
- No hay fecha de fin anunciada para el nivel gratuito.

## remove.bg (quitar el fondo)

- **50 llamadas gratis a la API al mes** en tamaño *preview* (hasta 0,25 megapíxeles). Por eso la app solo quita el fondo cuando el usuario toca **"Quitar fondo"**, y la identificación con IA siempre usa la foto original.
- Después de cada foto, la app muestra cuántas fotos gratis quedan en el mes.
- Si se acaban, la app avisa y permite guardar la prenda con la foto original.
- **Fecha límite:** remove.bg anunció que desde el **1 de diciembre de 2026 a las 9:00 a. m. (hora de Europa central; 3:00 a. m. en Colombia)** su sitio deja de estar disponible y la eliminación de fondos pasa a **Leonardo.Ai** (también de Canva). No está confirmado que la API ni las API keys sigan funcionando después de esa fecha. La entrega del 17 de noviembre no se ve afectada, pero después del 1 de diciembre habría que cambiar de servicio en `functions/src/fondo.js`.

## Configuración de las API keys

Las claves van en `functions/.secret.local` (plantilla: `functions/.secret.local.example`, campos `PEGA_AQUI_...`). Luego `scripts/configurar-claves.ps1` (Windows) o `scripts/configurar-claves.sh` las copia a Firebase y publica todo. A mano sería:

```bash
firebase functions:secrets:set GEMINI_API_KEY      # https://aistudio.google.com/apikey
firebase functions:secrets:set REMOVE_BG_API_KEY   # https://www.remove.bg/dashboard#api-key
firebase deploy --only functions
```

Para el servidor de prueba local, las mismas keys van en `functions/.secret.local`.
