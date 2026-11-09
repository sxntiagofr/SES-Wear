// Lógica del asistente de moda de SES Wear.
// No depende de Firebase ni de un servidor concreto: la usan tanto la Cloud
// Function (index.js) como el servidor de prueba local (servidor-prueba.js).

import { GoogleGenAI, ApiError, FinishReason } from "@google/genai";

// Modelos de Gemini con nivel gratuito, en orden de preferencia. Si el primero
// está saturado o se alcanzó su límite gratuito, se intenta con el siguiente.
// Con CHATBOT_MODEL en .secret.local se fuerza un solo modelo.
export const MODELOS = process.env.CHATBOT_MODEL
  ? [process.env.CHATBOT_MODEL]
  : ["gemini-3.5-flash", "gemini-flash-lite-latest"];

// Cada intento espera máximo 30 s y se reintenta una sola vez antes de pasar
// al siguiente modelo, para que el chat no se quede colgado.
const OPCIONES_HTTP = { timeout: 30_000, retryOptions: { attempts: 2 } };

const MAX_MENSAJES = 40;
const MAX_CARACTERES_POR_MENSAJE = 4000;

// Fotos de prendas: la app las reduce antes de enviarlas (máx. ~1024 px).
const TIPOS_IMAGEN = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const MAX_BYTES_IMAGEN = 4 * 1024 * 1024;
// Solo se reenvían a Gemini las fotos más recientes; las anteriores se
// reemplazan por una nota para no gastar cuota en cada mensaje.
const MAX_IMAGENES_EN_HISTORIAL = 3;
const PREGUNTA_FOTO_POR_DEFECTO = "¿Qué opinas de esta prenda y para qué ocasiones me sirve?";

const INSTRUCCIONES = `Eres el asistente de estilo de SES Wear, una app móvil que funciona como clóset digital inteligente. El eslogan de la app es "Tu estilo, más inteligente".

Tu trabajo es conversar con el usuario sobre su ropa y su forma de vestir: ideas de combinaciones, qué ponerse según la ocasión (casual, trabajo, universidad, deportivo, fiesta, entrevista) y el clima, colores que combinan, tendencias, y cómo proyectar la imagen que el usuario quiere. También puedes tener una conversación normal y amable si el usuario simplemente quiere charlar.

Forma de hablar:
- Español de Colombia, cercano y natural, tuteando al usuario.
- Usa el léxico colombiano de prendas: saco, buso, chaqueta, jean, tenis, chanclas, camiseta, blusa, pantaloneta, sudadera.
- Respuestas cortas y concretas, como en un chat del celular: normalmente entre 2 y 6 frases. Si das varias opciones, usa una lista corta con guiones.
- No uses títulos ni tablas. Puedes resaltar una palabra clave con **negrita**.
- Empieza a responder de inmediato, sin preámbulos.

Criterio:
- No impongas una única forma de vestir: adapta las sugerencias a los gustos del usuario y a lo que te cuente que tiene en su armario.
- Promueve el consumo responsable: antes de sugerir comprar algo, propone combinaciones con prendas que el usuario probablemente ya tiene.
- Si te falta información importante (ocasión, clima, estilo), haz una sola pregunta corta.
- Si al final de estas instrucciones aparece el ARMARIO DEL USUARIO (las prendas que guardó en la app), úsalo: recomienda combinaciones con esas prendas, nómbralas como aparecen y no inventes prendas que no estén en la lista. Nunca muestres los [id: ...] de las prendas.
- Si el armario está vacío o no aparece, dile que puede registrar sus prendas en la pestaña Armario de la app y pídele que te cuente qué tiene.

Cuando el usuario envíe una foto:
- Identifica la prenda en una frase: tipo, color, estilo y, si se nota, la tela o textura.
- Si pregunta por una ocasión, empieza con un veredicto claro: **Sí sirve**, **No es la mejor opción** o **Depende**, y explica por qué en una o dos frases (formalidad, clima, contexto).
- Si no sirve tal cual, di cómo adaptarla (con qué combinarla) o qué tipo de prenda funcionaría mejor.
- Si no menciona ninguna ocasión, dile para qué ocasiones sí funciona y propone una combinación.
- Si la foto no muestra ropa o no se ve bien la prenda, dilo con amabilidad y pide otra foto con buena luz y la prenda completa.
- Opina solo sobre la prenda, nunca sobre el cuerpo o el físico de la persona.`;

export const MENSAJE_RECHAZO =
  "Prefiero no responder eso. ¿Te ayudo con alguna idea de outfit o con algo de tu armario?";

export class ErrorDeEntrada extends Error {}

function validarImagen(imagen) {
  if (!imagen || typeof imagen.datos !== "string" || !TIPOS_IMAGEN.includes(imagen.tipo)) {
    throw new ErrorDeEntrada("La foto debe ser JPG, PNG, WEBP o HEIC.");
  }
  // Tamaño aproximado de la foto a partir del texto en base64.
  if (imagen.datos.length * 0.75 > MAX_BYTES_IMAGEN) {
    throw new ErrorDeEntrada("La foto es demasiado grande (máximo 4 MB).");
  }
  return { inlineData: { mimeType: imagen.tipo, data: imagen.datos } };
}

// Valida y limpia el historial que envía la app y lo convierte al formato de Gemini.
// Formato esperado: [{ rol: "usuario" | "asistente", texto: "...", imagen?: { tipo, datos } }, ...]
// `imagen` (solo en mensajes del usuario): foto en base64, p. ej. { tipo: "image/jpeg", datos: "..." }.
export function validarMensajes(mensajes) {
  if (!Array.isArray(mensajes) || mensajes.length === 0) {
    throw new ErrorDeEntrada("Debes enviar al menos un mensaje.");
  }

  const recientes = mensajes.slice(-MAX_MENSAJES);
  const posicionesConFoto = recientes
    .map((m, i) => (m?.imagen && m.rol === "usuario" ? i : -1))
    .filter((i) => i >= 0);
  const fotosQueSeEnvian = new Set(posicionesConFoto.slice(-MAX_IMAGENES_EN_HISTORIAL));

  const limpios = recientes.map((m, i) => {
    if (!m || (m.rol !== "usuario" && m.rol !== "asistente")) {
      throw new ErrorDeEntrada('Cada mensaje debe tener rol "usuario" o "asistente".');
    }
    const tieneFoto = m.rol === "usuario" && Boolean(m.imagen);
    let texto = typeof m.texto === "string" ? m.texto.trim() : "";
    if (!texto && tieneFoto) texto = PREGUNTA_FOTO_POR_DEFECTO;
    if (!texto) {
      throw new ErrorDeEntrada("Hay un mensaje vacío.");
    }
    if (texto.length > MAX_CARACTERES_POR_MENSAJE) {
      throw new ErrorDeEntrada(`Cada mensaje puede tener máximo ${MAX_CARACTERES_POR_MENSAJE} caracteres.`);
    }

    const parts = [];
    if (tieneFoto && fotosQueSeEnvian.has(i)) {
      parts.push(validarImagen(m.imagen));
    } else if (tieneFoto) {
      texto = `[El usuario envió antes una foto de una prenda]\n${texto}`;
    }
    parts.push({ text: texto });
    return { role: m.rol === "usuario" ? "user" : "model", parts };
  });

  // La conversación debe empezar y terminar con un mensaje del usuario.
  while (limpios.length && limpios[0].role !== "user") limpios.shift();
  if (!limpios.length || limpios.at(-1).role !== "user") {
    throw new ErrorDeEntrada("El último mensaje debe ser del usuario.");
  }
  return limpios;
}

// Envía la conversación a Gemini y devuelve la respuesta completa.
// `alTexto` (opcional) recibe cada fragmento de texto a medida que llega,
// para mostrar la respuesta en vivo.
export async function responder(mensajes, { apiKey, alTexto, contexto } = {}) {
  const historial = validarMensajes(mensajes);
  // `contexto` (opcional): perfil y prendas del usuario leídos de Firestore (src/datos.js).
  const instrucciones = contexto
    ? `${INSTRUCCIONES}\n\n--- Datos del usuario (desde la base de datos de la app) ---\n${contexto}`
    : INSTRUCCIONES;
  const ai = new GoogleGenAI({ apiKey, httpOptions: OPCIONES_HTTP });

  let texto = "";
  let bloqueado = false;
  for (const [i, modelo] of MODELOS.entries()) {
    try {
      const stream = await ai.models.generateContentStream({
        model: modelo,
        contents: historial,
        config: { systemInstruction: instrucciones },
      });
      for await (const fragmento of stream) {
        if (fragmento.promptFeedback?.blockReason) bloqueado = true;
        if (fragmento.candidates?.[0]?.finishReason === FinishReason.SAFETY) bloqueado = true;
        const parte = fragmento.text;
        if (parte) {
          texto += parte;
          alTexto?.(parte);
        }
      }
      break;
    } catch (error) {
      // Solo se cambia de modelo si todavía no se ha mostrado nada al usuario.
      const ultimo = i === MODELOS.length - 1;
      if (ultimo || texto || !esErrorTemporal(error)) throw error;
      console.warn(`[asistente] ${modelo} no disponible, se intenta con ${MODELOS[i + 1]}`);
    }
  }

  if (bloqueado) {
    return { texto: MENSAJE_RECHAZO, rechazado: true };
  }
  texto = texto.trim();
  if (!texto) {
    throw new Error("Gemini devolvió una respuesta vacía.");
  }
  return { texto, rechazado: false };
}

// Saturación, límite gratuito, error del servidor o tiempo de espera agotado.
function esErrorTemporal(error) {
  if (error instanceof ApiError) {
    return error.status === 408 || error.status === 429 || error.status >= 500;
  }
  return !(error instanceof ErrorDeEntrada);
}

// Convierte los errores de la API en mensajes entendibles para el usuario.
export function describirError(error) {
  if (error instanceof ErrorDeEntrada) {
    return { estado: 400, mensaje: error.message };
  }
  if (error instanceof ApiError) {
    if (error.status === 429) {
      return { estado: 429, mensaje: "Se alcanzó el límite gratuito de Gemini por ahora. Espera un minuto e inténtalo de nuevo." };
    }
    if (error.status === 400 && /api key/i.test(error.message)) {
      return { estado: 500, mensaje: "La API key de Gemini no es válida. Revisa functions/.secret.local." };
    }
    if (error.status === 401 || error.status === 403) {
      return { estado: 500, mensaje: "La API key de Gemini no tiene permiso para usar este modelo." };
    }
    if (error.status >= 500) {
      return { estado: 503, mensaje: "Gemini no está disponible en este momento. Inténtalo de nuevo." };
    }
    return { estado: 502, mensaje: `Gemini rechazó la solicitud (${error.status}).` };
  }
  if (error?.name === "AbortError" || error?.name === "TimeoutError") {
    return { estado: 504, mensaje: "Gemini tardó demasiado en responder. Inténtalo de nuevo." };
  }
  if (error instanceof TypeError && /fetch/i.test(error.message)) {
    return { estado: 503, mensaje: "No se pudo conectar con Gemini. Revisa tu conexión a internet." };
  }
  return { estado: 500, mensaje: "Ocurrió un error inesperado en el asistente." };
}
