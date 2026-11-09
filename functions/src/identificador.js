// Identificación automática de prendas a partir de una foto (RF-01, parte de IA).
// La app toma la foto, la envía en base64 y Gemini devuelve los atributos de la
// prenda en JSON para llenar el formulario del armario.
// Igual que asistente.js, no depende de Firebase: lo usan la Cloud Function
// `identificarPrenda` (index.js) y el servidor de prueba local.

import { GoogleGenAI, ApiError, Type } from "@google/genai";
import { MODELOS, ErrorDeEntrada } from "./asistente.js";

const OPCIONES_HTTP = { timeout: 30_000, retryOptions: { attempts: 2 } };
const TIPOS_IMAGEN = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const MAX_BYTES_IMAGEN = 4 * 1024 * 1024;

// Valores cerrados para que la app pueda usarlos en filtros (RF-02).
export const TIPOS = ["superior", "inferior", "calzado", "accesorio", "enterizo", "abrigo"];
export const FORMALIDADES = ["casual", "deportivo", "semiformal", "formal", "fiesta"];
export const ESTACIONES = ["calor", "frío", "lluvia", "todo el año"];

const INSTRUCCIONES = `Eres el módulo de reconocimiento de prendas de SES Wear, una app de armario digital en Colombia.
Recibes la foto de UNA prenda de ropa, calzado o accesorio y devuelves sus atributos para registrarla en el armario del usuario.

Reglas:
- Responde en español de Colombia con el léxico local: saco, buso, chaqueta, jean, tenis, chanclas, camiseta, blusa, pantaloneta, sudadera, camisa, vestido, falda.
- "nombre": nombre corto y descriptivo, p. ej. "Jean azul clásico" o "Buso gris con capota".
- "categoria": la prenda concreta en minúscula, p. ej. "jean", "camiseta", "tenis", "buso", "vestido".
- Colores en minúscula y simples (negro, blanco, gris, azul oscuro, beige, rojo...). "colorSecundario" vacío si la prenda es de un solo color.
- "tela": la tela o textura que se ve (denim, algodón, lana, cuero, poliéster, lino, seda, punto...). Si no se distingue, la más probable.
- "estilo": una o dos palabras (clásico, urbano, deportivo, elegante, bohemio, minimalista...).
- "etiquetas": de 2 a 5 palabras útiles para buscar la prenda (estampado, manga larga, oversize, rasgado...).
- Si en la foto hay varias prendas, describe la más visible o la que está en el centro.
- Si la foto no muestra ropa, calzado ni accesorios, pon "esPrenda": false y deja los demás campos vacíos.
- Describe solo la prenda, nunca a la persona que la lleva puesta.`;

const ESQUEMA = {
  type: Type.OBJECT,
  properties: {
    esPrenda: { type: Type.BOOLEAN },
    nombre: { type: Type.STRING },
    tipo: { type: Type.STRING, enum: TIPOS },
    categoria: { type: Type.STRING },
    colorPrimario: { type: Type.STRING },
    colorSecundario: { type: Type.STRING },
    tela: { type: Type.STRING },
    estilo: { type: Type.STRING },
    formalidad: { type: Type.STRING, enum: FORMALIDADES },
    estacion: { type: Type.STRING, enum: ESTACIONES },
    etiquetas: { type: Type.ARRAY, items: { type: Type.STRING } },
  },
  required: ["esPrenda", "nombre", "tipo", "categoria", "colorPrimario", "tela", "estilo", "formalidad", "estacion"],
  propertyOrdering: [
    "esPrenda", "nombre", "tipo", "categoria", "colorPrimario", "colorSecundario",
    "tela", "estilo", "formalidad", "estacion", "etiquetas",
  ],
};

export function validarImagen(imagen) {
  if (!imagen || typeof imagen.datos !== "string" || !TIPOS_IMAGEN.includes(imagen.tipo)) {
    throw new ErrorDeEntrada("La foto debe ser JPG, PNG, WEBP o HEIC.");
  }
  if (imagen.datos.length * 0.75 > MAX_BYTES_IMAGEN) {
    throw new ErrorDeEntrada("La foto es demasiado grande (máximo 4 MB).");
  }
  return { inlineData: { mimeType: imagen.tipo, data: imagen.datos } };
}

const texto = (v) => (typeof v === "string" ? v.trim() : "");
const enLista = (v, lista, porDefecto) => (lista.includes(texto(v)) ? texto(v) : porDefecto);

// Deja la respuesta de Gemini con la forma exacta que espera la app.
export function normalizarPrenda(bruto) {
  const esPrenda = bruto?.esPrenda !== false;
  return {
    esPrenda,
    nombre: texto(bruto?.nombre),
    tipo: enLista(bruto?.tipo, TIPOS, "superior"),
    categoria: texto(bruto?.categoria).toLowerCase(),
    colorPrimario: texto(bruto?.colorPrimario).toLowerCase(),
    colorSecundario: texto(bruto?.colorSecundario).toLowerCase(),
    tela: texto(bruto?.tela).toLowerCase(),
    estilo: texto(bruto?.estilo).toLowerCase(),
    formalidad: enLista(bruto?.formalidad, FORMALIDADES, "casual"),
    estacion: enLista(bruto?.estacion, ESTACIONES, "todo el año"),
    etiquetas: Array.isArray(bruto?.etiquetas)
      ? bruto.etiquetas.map(texto).filter(Boolean).slice(0, 5)
      : [],
  };
}

function esErrorTemporal(error) {
  if (error instanceof ApiError) {
    return error.status === 408 || error.status === 429 || error.status >= 500;
  }
  return !(error instanceof ErrorDeEntrada);
}

// Recibe { tipo, datos } (foto en base64) y devuelve los atributos de la prenda.
export async function identificarPrenda(imagen, { apiKey } = {}) {
  const foto = validarImagen(imagen);
  const ai = new GoogleGenAI({ apiKey, httpOptions: OPCIONES_HTTP });

  for (const [i, modelo] of MODELOS.entries()) {
    try {
      const respuesta = await ai.models.generateContent({
        model: modelo,
        contents: [{ role: "user", parts: [foto, { text: "Identifica esta prenda." }] }],
        config: {
          systemInstruction: INSTRUCCIONES,
          responseMimeType: "application/json",
          responseSchema: ESQUEMA,
          temperature: 0.2,
        },
      });
      if (!respuesta.text) {
        throw new ErrorDeEntrada("No se pudo analizar la foto. Intenta con otra foto con buena luz.");
      }
      return normalizarPrenda(JSON.parse(respuesta.text));
    } catch (error) {
      const ultimo = i === MODELOS.length - 1;
      if (ultimo || !esErrorTemporal(error)) throw error;
      console.warn(`[identificador] ${modelo} no disponible, se intenta con ${MODELOS[i + 1]}`);
    }
  }
}
