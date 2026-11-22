// Cloud Functions de SES Wear.
// La IA (asistente, identificar prendas e ideas de outfits) corre en la app con
// Firebase AI Logic; aquí solo queda lo que necesita un servidor:
// - quitarFondo     foto sin fondo con remove.bg (la API key no puede ir en la app)
// - eliminarCuenta  borra la cuenta y todos sus datos (Ley 1581)
// La app las llama con FirebaseFunctions.instance.httpsCallable(nombre).
// (src/asistente.js, src/identificador.js y src/outfits.js siguen sirviendo al
// servidor de prueba local: npm run prueba.)

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth } from "firebase-admin/auth";
import { ErrorDeEntrada } from "./src/asistente.js";
import { quitarFondo as quitarFondoRemoveBg, ErrorFondo } from "./src/fondo.js";
import { consumirCupo, ErrorDeLimite } from "./src/limites.js";
import { eliminarDatosDeUsuario } from "./src/cuenta.js";

initializeApp();
const db = getFirestore();

// La API key de remove.bg vive en Secret Manager de Firebase, nunca en el código
// ni en la app. Se configura con scripts/configurar-claves (o firebase functions:secrets:set).
const REMOVE_BG_API_KEY = defineSecret("REMOVE_BG_API_KEY");

// App Check: cuando la app ya esté registrada en Firebase Console → App Check
// (Play Integrity / App Attest), poner EXIGIR_APP_CHECK=true en functions/.env
// para rechazar llamadas que no vengan de la app oficial.
const EXIGIR_APP_CHECK = process.env.EXIGIR_APP_CHECK === "true";

// Verifica sesión (y App Check si está activo) y descuenta un uso del cupo diario.
async function autorizar(request, funcion, mensajeSinSesion) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", mensajeSinSesion);
  }
  if (EXIGIR_APP_CHECK && !request.app) {
    throw new HttpsError("failed-precondition", "Esta solicitud no viene de la app oficial de SES Wear.");
  }
  try {
    await consumirCupo(db, request.auth.uid, funcion);
  } catch (error) {
    if (error instanceof ErrorDeLimite) throw new HttpsError("resource-exhausted", error.message);
    // Si el contador falla, no se bloquea al usuario.
    logger.warn("No se pudo registrar el uso", error);
  }
  return request.auth.uid;
}

export const quitarFondo = onCall(
  { secrets: [REMOVE_BG_API_KEY], timeoutSeconds: 60 },
  async (request) => {
    await autorizar(request, "quitarFondo", "Debes iniciar sesión para quitar el fondo.");
    try {
      return await quitarFondoRemoveBg(request.data?.imagen, { apiKey: REMOVE_BG_API_KEY.value() });
    } catch (error) {
      if (error instanceof ErrorDeEntrada) {
        throw new HttpsError("invalid-argument", error.message);
      }
      if (error instanceof ErrorFondo) {
        logger.warn("remove.bg", error.message);
        const codigo = error.estado === 429 ? "resource-exhausted" : error.estado === 400 ? "invalid-argument" : "unavailable";
        throw new HttpsError(codigo, error.message);
      }
      logger.error("Error al quitar el fondo", error);
      throw new HttpsError("internal", "Ocurrió un error inesperado al quitar el fondo.");
    }
  },
);

// Borra la cuenta y todos los datos del usuario (Perfil → Eliminar cuenta).
export const eliminarCuenta = onCall({ timeoutSeconds: 300 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión para eliminar tu cuenta.");
  }
  if (request.data?.confirmacion !== "ELIMINAR") {
    throw new HttpsError("invalid-argument", "Falta la confirmación para eliminar la cuenta.");
  }
  try {
    await eliminarDatosDeUsuario(
      { db, bucket: getStorage().bucket(), auth: getAuth(), logger },
      request.auth.uid,
    );
    return { eliminada: true };
  } catch (error) {
    logger.error("Error al eliminar la cuenta", error);
    throw new HttpsError("internal", "No se pudo eliminar la cuenta. Inténtalo de nuevo más tarde.");
  }
});
