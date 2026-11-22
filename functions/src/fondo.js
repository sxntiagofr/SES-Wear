// Quitar el fondo de la foto de una prenda con la API de remove.bg.
// No depende de Firebase: lo usan la Cloud Function `quitarFondo` (index.js) y el
// servidor de prueba local.
//
// Plan gratuito de remove.bg: 50 llamadas a la API al mes por cuenta, en tamaño
// "preview" (hasta 0,25 megapíxeles, p. ej. 625 × 400). El cupo es para TODA la app,
// no por usuario. Ver docs/limites-gratuitos.md.
// Aviso: remove.bg anunció que desde el 1 de diciembre de 2026 su servicio pasa a
// Leonardo.Ai; si la API deja de responder, la app sigue funcionando con la foto original.

import { ErrorDeEntrada } from "./asistente.js";
import { validarImagen } from "./identificador.js";

const URL_API = "https://api.remove.bg/v1.0";
// "preview" es el tamaño que cubre el plan gratuito. Se puede cambiar con
// REMOVEBG_SIZE en .secret.local (p. ej. "auto" si se compran créditos).
const TAMANO = process.env.REMOVEBG_SIZE || "preview";
const TIPOS_ACEPTADOS = ["image/jpeg", "image/png", "image/webp"];

// Error de remove.bg con un mensaje entendible para el usuario.
export class ErrorFondo extends Error {
  constructor(estado, mensaje) {
    super(mensaje);
    this.estado = estado;
  }
}

function errorDesdeRespuesta(estado, cuerpo) {
  const detalle = cuerpo?.errors?.[0]?.title ?? "";
  if (estado === 402) {
    return new ErrorFondo(429, "Se acabaron las fotos gratis para quitar el fondo este mes (50 al mes). Puedes guardar la prenda con la foto original.");
  }
  if (estado === 429) {
    return new ErrorFondo(429, "Demasiadas fotos al mismo tiempo. Espera un momento e inténtalo de nuevo.");
  }
  if (estado === 401 || estado === 403) {
    return new ErrorFondo(500, "La API key de remove.bg no es válida. Revisa REMOVE_BG_API_KEY.");
  }
  if (estado === 400) {
    if (/foreground/i.test(detalle)) {
      return new ErrorFondo(400, "No se encontró la prenda en la foto para quitarle el fondo. Prueba con otra foto.");
    }
    return new ErrorFondo(400, `remove.bg no pudo procesar la foto${detalle ? ` (${detalle})` : ""}.`);
  }
  if (estado === 404 || estado === 410) {
    return new ErrorFondo(503, "El servicio para quitar el fondo ya no está disponible. Puedes guardar la prenda con la foto original.");
  }
  return new ErrorFondo(503, "El servicio para quitar el fondo no está disponible en este momento. Inténtalo más tarde.");
}

// Fotos gratis que le quedan a la cuenta este mes (null si no se pudo consultar).
// Consultar la cuenta no gasta créditos.
export async function consultarCupo(apiKey) {
  try {
    const r = await fetch(`${URL_API}/account`, {
      headers: { "X-Api-Key": apiKey, Accept: "application/json" },
      signal: AbortSignal.timeout(10_000),
    });
    if (!r.ok) return null;
    const cuerpo = await r.json();
    const llamadas = cuerpo?.data?.attributes?.api?.free_calls;
    return Number.isFinite(llamadas) ? llamadas : null;
  } catch {
    return null;
  }
}

// Recibe { tipo, datos } (base64) y devuelve la prenda sin fondo en PNG (base64, fondo transparente).
export async function quitarFondo(imagen, { apiKey } = {}) {
  const { inlineData } = validarImagen(imagen);
  if (!TIPOS_ACEPTADOS.includes(inlineData.mimeType)) {
    throw new ErrorDeEntrada("Para quitar el fondo la foto debe ser JPG, PNG o WEBP.");
  }
  if (!apiKey || apiKey.startsWith("PEGA_AQUI")) {
    throw new ErrorFondo(500, "Falta la API key de remove.bg: ponla en functions/.secret.local (REMOVE_BG_API_KEY).");
  }

  const extension = inlineData.mimeType.split("/")[1];
  const formulario = new FormData();
  formulario.append(
    "image_file",
    new Blob([Buffer.from(inlineData.data, "base64")], { type: inlineData.mimeType }),
    `prenda.${extension}`,
  );
  formulario.append("size", TAMANO);
  formulario.append("format", "png");

  let respuesta;
  try {
    respuesta = await fetch(`${URL_API}/removebg`, {
      method: "POST",
      headers: { "X-Api-Key": apiKey, Accept: "application/json" },
      body: formulario,
      signal: AbortSignal.timeout(30_000),
    });
  } catch {
    throw new ErrorFondo(504, "remove.bg tardó demasiado o no respondió. Inténtalo de nuevo.");
  }

  const cuerpo = await respuesta.json().catch(() => null);
  if (!respuesta.ok) throw errorDesdeRespuesta(respuesta.status, cuerpo);

  const resultado = cuerpo?.data?.result_b64;
  if (typeof resultado !== "string" || !resultado) {
    throw new ErrorFondo(502, "remove.bg devolvió una respuesta vacía.");
  }
  return {
    imagen: { tipo: "image/png", datos: resultado },
    creditosUsados: Number(respuesta.headers.get("x-credits-charged")) || 0,
    fotosGratisRestantes: await consultarCupo(apiKey),
  };
}
