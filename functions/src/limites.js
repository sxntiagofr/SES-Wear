// Límite de usos diarios por usuario para las funciones que gastan cupos
// gratuitos compartidos por toda la app (Gemini y remove.bg).
// Sin esto, un solo usuario podría agotar el cupo de todos.
//
// Se guarda en users/{uid}/uso/{AAAA-MM-DD} (hora de Colombia), p. ej.
// { chat: 12, identificarPrenda: 3 }. La app puede leerlo pero no escribirlo
// (ver firestore.rules); solo lo modifica el servidor.

import { FieldValue } from "firebase-admin/firestore";

export const LIMITES_DIARIOS = {
  chat: 100,
  identificarPrenda: 40,
  generarOutfits: 30,
  // remove.bg regala 50 fotos al MES para toda la app.
  quitarFondo: 5,
};

export class ErrorDeLimite extends Error {}

// Fecha AAAA-MM-DD en hora de Colombia (el cupo se renueva a medianoche).
export function fechaColombia(ahora = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Bogota" }).format(ahora);
}

// Suma un uso de `funcion` para el usuario o lanza ErrorDeLimite si ya llegó al tope.
export async function consumirCupo(db, uid, funcion, { ahora = new Date(), limites = LIMITES_DIARIOS } = {}) {
  const limite = limites[funcion];
  if (!limite) return;
  const ref = db.collection("users").doc(uid).collection("uso").doc(fechaColombia(ahora));
  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const usados = doc.exists ? Number(doc.data()?.[funcion]) || 0 : 0;
    if (usados >= limite) {
      throw new ErrorDeLimite(
        `Llegaste al límite de ${limite} usos diarios de esta función. Vuelve a intentarlo mañana.`,
      );
    }
    tx.set(ref, { [funcion]: usados + 1, actualizado: FieldValue.serverTimestamp() }, { merge: true });
  });
}
