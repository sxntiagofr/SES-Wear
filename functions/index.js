// Cloud Functions de SES Wear.
// La app Flutter llama a `chat` con el paquete cloud_functions:
// FirebaseFunctions.instance.httpsCallable('chat').call({'mensajes': [...], 'conversacionId': '...'})

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { responder, describirError, ErrorDeEntrada } from "./src/asistente.js";
import { cargarContextoUsuario, guardarIntercambio } from "./src/datos.js";

initializeApp();
const db = getFirestore();

// La API key de Gemini vive en Secret Manager de Firebase, nunca en el código ni en la app.
// Se configura una sola vez con: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

export const chat = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request, response) => {
    // Solo usuarios con sesión iniciada en la app pueden usar el asistente,
    // para que nadie más gaste la API key.
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión para usar el asistente.");
    }
    const uid = request.auth.uid;
    const mensajes = request.data?.mensajes;

    // 1. Base de datos → asistente: perfil y prendas del armario del usuario.
    let contexto = "";
    try {
      contexto = await cargarContextoUsuario(db, uid);
    } catch (error) {
      logger.warn("No se pudo leer el armario del usuario; se responde sin él", error);
    }

    // 2. Respuesta de Gemini.
    let respuesta;
    try {
      respuesta = await responder(mensajes, {
        apiKey: GEMINI_API_KEY.value(),
        contexto,
        // Si la app pide la respuesta en vivo, se envía por fragmentos.
        alTexto: request.acceptsStreaming ? (texto) => response.sendChunk(texto) : undefined,
      });
    } catch (error) {
      if (error instanceof ErrorDeEntrada) {
        throw new HttpsError("invalid-argument", error.message);
      }
      logger.error("Error en el asistente", error);
      throw new HttpsError("internal", describirError(error).mensaje);
    }

    // 3. Asistente → base de datos: se guarda el intercambio en el historial.
    let conversacionId = request.data?.conversacionId ?? null;
    try {
      conversacionId = await guardarIntercambio(db, uid, { conversacionId, mensajes, respuesta });
    } catch (error) {
      logger.error("No se pudo guardar la conversación", error);
    }

    return { ...respuesta, conversacionId };
  },
);
