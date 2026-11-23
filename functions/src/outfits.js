// Generador de outfits con IA (RF-03).
// Recibe las prendas del armario (ya leídas de Firestore) y le pide a Gemini
// combinaciones para una ocasión y un clima. Gemini solo puede usar los ids de
// prendas que existen; todo lo demás se descarta al normalizar.
// Igual que asistente.js, no depende de Firebase.

import { GoogleGenAI, ApiError, Type } from "@google/genai";
import { MODELOS, ErrorDeEntrada } from "./asistente.js";

export const OCASIONES = ["casual", "universidad", "trabajo", "deportivo", "fiesta", "formal"];
export const CLIMAS = ["calor", "frío", "lluvia", "cualquiera"];
const MAX_PRENDAS = 150;
const MAX_EXCLUIDOS = 30;
const OPCIONES_HTTP = { timeout: 30_000, retryOptions: { attempts: 2 } };

const INSTRUCCIONES = `Eres el generador de outfits de SES Wear, una app de armario digital en Colombia.
Recibes la lista de prendas del usuario (cada una con su id) y armas combinaciones completas para la ocasión y el clima pedidos.

Reglas:
- Usa SOLO prendas de la lista, referenciadas por su id exacto. Nunca inventes prendas ni ids.
- Un outfit completo lleva: una prenda superior y una inferior (o un enterizo), y calzado si hay. Agrega abrigo si el clima es frío o lluvia y hay uno. Un accesorio es opcional.
- Respeta la formalidad de la ocasión y combina colores con criterio (neutros con todo; máximo dos colores fuertes).
- Promueve el consumo responsable: prefiere prendas poco usadas cuando combinen bien.
- No repitas ninguna de las combinaciones que aparecen como "ya mostradas".
- "nombre": 2 a 5 palabras, p. ej. "Urbano relajado para la U".
- "explicacion": una o dos frases en español de Colombia, tuteando, diciendo por qué funciona.
- Si no hay prendas suficientes para un outfit completo, devuelve la lista vacía.`;

const ESQUEMA = {
  type: Type.OBJECT,
  properties: {
    outfits: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          nombre: { type: Type.STRING },
          prendaIds: { type: Type.ARRAY, items: { type: Type.STRING } },
          explicacion: { type: Type.STRING },
        },
        required: ["nombre", "prendaIds", "explicacion"],
        propertyOrdering: ["nombre", "prendaIds", "explicacion"],
      },
    },
  },
  required: ["outfits"],
};

const texto = (v) => (typeof v === "string" ? v.trim() : "");

// Valida lo que envía la app: { ocasion, clima, cantidad?, excluir?: [[ids...], ...], coleccionId? }
export function validarSolicitud(datos) {
  const ocasion = texto(datos?.ocasion);
  if (!OCASIONES.includes(ocasion)) {
    throw new ErrorDeEntrada(`La ocasión debe ser una de: ${OCASIONES.join(", ")}.`);
  }
  const clima = CLIMAS.includes(texto(datos?.clima)) ? texto(datos.clima) : "cualquiera";
  const cantidad = Math.min(5, Math.max(1, Number.parseInt(datos?.cantidad, 10) || 3));
  const excluir = Array.isArray(datos?.excluir)
    ? datos.excluir
        .filter(Array.isArray)
        .slice(-MAX_EXCLUIDOS)
        .map((ids) => ids.filter((id) => typeof id === "string"))
    : [];
  const coleccionId = /^[A-Za-z0-9_-]{1,64}$/.test(texto(datos?.coleccionId)) ? texto(datos.coleccionId) : null;
  return { ocasion, clima, cantidad, excluir, coleccionId };
}

// Una línea por prenda para el prompt.
export function describirPrendas(prendas) {
  return prendas
    .slice(0, MAX_PRENDAS)
    .map((p) => {
      const datos = [
        texto(p.tipo),
        texto(p.categoria),
        [texto(p.colorPrimario), texto(p.colorSecundario)].filter(Boolean).join(" y "),
        texto(p.formalidad),
        texto(p.estacion),
        Number.isFinite(p.vecesUsada) ? `usada ${p.vecesUsada}` : "",
      ].filter(Boolean);
      return `- id ${p.id}: ${texto(p.nombre) || texto(p.categoria) || "prenda"} (${datos.join(", ")})`;
    })
    .join("\n");
}

const clave = (ids) => [...ids].sort().join("|");

// Deja solo outfits válidos: ids existentes, sin repetir, al menos 2 prendas,
// y que no estén entre los ya mostrados.
export function normalizarOutfits(bruto, idsValidos, excluir = []) {
  const validos = new Set(idsValidos);
  const vistos = new Set(excluir.map(clave));
  const resultado = [];
  for (const o of Array.isArray(bruto?.outfits) ? bruto.outfits : []) {
    const ids = [...new Set((Array.isArray(o?.prendaIds) ? o.prendaIds : []).filter((id) => validos.has(id)))];
    if (ids.length < 2 || vistos.has(clave(ids))) continue;
    vistos.add(clave(ids));
    resultado.push({
      nombre: texto(o.nombre) || "Outfit sugerido",
      prendaIds: ids,
      explicacion: texto(o.explicacion),
    });
  }
  return resultado;
}

function esErrorTemporal(error) {
  if (error instanceof ApiError) {
    return error.status === 408 || error.status === 429 || error.status >= 500;
  }
  return !(error instanceof ErrorDeEntrada);
}

// prendas: [{ id, nombre, tipo, ... }] leídas de Firestore.
export async function generarOutfits({ prendas, ocasion, clima, cantidad, excluir }, { apiKey } = {}) {
  if (!Array.isArray(prendas) || prendas.length < 2) {
    throw new ErrorDeEntrada("Necesitas al menos 2 prendas en tu armario (o en la colección) para armar un outfit.");
  }
  const ai = new GoogleGenAI({ apiKey, httpOptions: OPCIONES_HTTP });
  const yaMostradas = excluir.length
    ? `\n\nCombinaciones ya mostradas (no las repitas):\n${excluir.map((ids) => `- ${ids.join(", ")}`).join("\n")}`
    : "";
  const pedido = `Ocasión: ${ocasion}. Clima: ${clima}. Arma ${cantidad} outfits distintos.\n\nPrendas del usuario:\n${describirPrendas(prendas)}${yaMostradas}`;

  for (const [i, modelo] of MODELOS.entries()) {
    try {
      const respuesta = await ai.models.generateContent({
        model: modelo,
        contents: [{ role: "user", parts: [{ text: pedido }] }],
        config: {
          systemInstruction: INSTRUCCIONES,
          responseMimeType: "application/json",
          responseSchema: ESQUEMA,
          temperature: 0.7,
        },
      });
      if (!respuesta.text) throw new Error("Gemini devolvió una respuesta vacía.");
      const outfits = normalizarOutfits(JSON.parse(respuesta.text), prendas.map((p) => p.id), excluir);
      return { outfits: outfits.slice(0, cantidad) };
    } catch (error) {
      const ultimo = i === MODELOS.length - 1;
      if (ultimo || !esErrorTemporal(error)) throw error;
      console.warn(`[outfits] ${modelo} no disponible, se intenta con ${MODELOS[i + 1]}`);
    }
  }
}
