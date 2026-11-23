// Crea la cuenta demo de SES Wear en los EMULADORES de Firebase (nunca en el
// proyecto real): perfil, prendas con foto, outfits, calendario, una colección
// y una conversación con el asistente.
// Lo ejecuta scripts/demo/iniciar-demo.ps1; necesita `npm install` en functions/.
//
// Cuenta: demo@seswear.co  /  moda2026

import { createRequire } from "node:module";
import { randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const aqui = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(aqui, "../../functions/package.json"));

process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= "127.0.0.1:9199";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

const BUCKET = "ses-wear.firebasestorage.app";
const CORREO = "demo@seswear.co";
const CLAVE = "moda2026";

initializeApp({ projectId: "ses-wear", storageBucket: BUCKET });
const db = getFirestore();
const auth = getAuth();
const bucket = getStorage().bucket();

// Si ya existe, se borra para empezar de cero.
try {
  const anterior = await auth.getUserByEmail(CORREO);
  await db.recursiveDelete(db.doc(`users/${anterior.uid}`));
  await auth.deleteUser(anterior.uid);
} catch {
  // No existía.
}

const { uid } = await auth.createUser({ email: CORREO, password: CLAVE, displayName: "Ana Demo" });
const ahora = Date.now();
const dia = 24 * 60 * 60 * 1000;
const ts = (ms) => Timestamp.fromMillis(ms);
const fecha = (ms) => new Intl.DateTimeFormat("en-CA", { timeZone: "America/Bogota" }).format(new Date(ms));

await db.doc(`users/${uid}`).set({
  email: CORREO, nombre: "Ana", apellido: "Demo", telefono: "3001234567", ciudad: "Bogotá",
  fotoUrl: null, proveedor: "password", rol: "usuario", locale: "es-CO",
  preferencias: { estilos: ["urbano", "minimalista"], colores: ["lila", "negro"], ocasiones: ["universidad", "trabajo"] },
  consentimientoDatos: { aceptado: true, fecha: ts(ahora), version: "1.0" },
  fechaRegistro: ts(ahora - 60 * dia), ultimoAcceso: ts(ahora),
});

// [id, foto, nombre, tipo, categoría, color, tela, estilo, formalidad, estación, usos, precio, días desde el último uso]
const prendas = [
  ["camisa-lila", "Camisa lila", "superior", "camisa", "lila", "algodón", "clásico", "semiformal", "todo el año", 9, 85000, 2],
  ["camisa-celeste", "Camisa celeste", "superior", "camisa", "celeste", "lino", "clásico", "semiformal", "calor", 3, 70000, 20],
  ["camiseta-blanca", "Camiseta blanca", "superior", "camiseta", "blanco", "algodón", "minimalista", "casual", "todo el año", 15, 35000, 1],
  ["chaqueta-negra", "Chaqueta negra", "abrigo", "chaqueta", "negro", "denim", "urbano", "casual", "frío", 6, 180000, 5],
  ["jean-azul", "Jean azul", "inferior", "jean", "azul", "denim", "clásico", "casual", "todo el año", 20, 120000, 1],
  ["pantalon-negro", "Pantalón negro", "inferior", "pantalón", "negro", "poliéster", "elegante", "formal", "todo el año", 4, 110000, 30],
  ["tenis-blancos", "Tenis blancos", "calzado", "tenis", "blanco", "cuero", "urbano", "casual", "todo el año", 18, 220000, 1],
  ["bolso-lila", "Bolso lila", "accesorio", "bolso", "lila", "cuero", "elegante", "semiformal", "todo el año", 0, 150000, null],
];

let orden = 0;
for (const [id, nombre, tipo, categoria, color, tela, estilo, formalidad, estacion, usos, precio, diasUso] of prendas) {
  const ruta = `users/${uid}/prendas/${id}.png`;
  const token = randomUUID();
  await bucket.upload(path.join(aqui, "fotos", `${id}.png`), {
    destination: ruta,
    metadata: { contentType: "image/png", metadata: { firebaseStorageDownloadTokens: token } },
  });
  const fotoUrl = `http://127.0.0.1:9199/v0/b/${BUCKET}/o/${encodeURIComponent(ruta)}?alt=media&token=${token}`;
  await db.doc(`users/${uid}/prendas/${id}`).set({
    nombre, tipo, categoria, colorPrimario: color, colorSecundario: "", tela, estilo, formalidad, estacion,
    etiquetas: [estilo, categoria], precio, fotoUrl, vecesUsada: usos, identificadaPorIA: true,
    ...(diasUso === null ? {} : { ultimoUso: ts(ahora - diasUso * dia) }),
    fechaCreacion: ts(ahora - 45 * dia - orden++ * 1000),
  });
}

const outfits = [
  ["casual-viernes", "Casual viernes", ["camiseta-blanca", "jean-azul", "tenis-blancos"], "casual", true, 5, "manual"],
  ["oficina", "Oficina lila", ["camisa-lila", "pantalon-negro", "bolso-lila"], "trabajo", false, 4, "local"],
  ["urbano-frio", "Urbano para el frío", ["camiseta-blanca", "chaqueta-negra", "jean-azul", "tenis-blancos"], "universidad", true, 0, "ia"],
];
for (const [id, nombre, prendaIds, ocasion, favorito, calificacion, origen] of outfits) {
  await db.doc(`users/${uid}/outfits/${id}`).set({
    nombre, prendaIds, ocasion, clima: "cualquiera", favorito, calificacion, origen,
    explicacion: "Combina neutros con un toque de color; le das uso a prendas que tienes.",
    fechaCreacion: ts(ahora - outfits.findIndex((o) => o[0] === id) * 1000),
  });
}

for (const [enDias, outfitId] of [[0, "casual-viernes"], [1, "oficina"], [3, "urbano-frio"]]) {
  const o = outfits.find((x) => x[0] === outfitId);
  const f = fecha(ahora + enDias * dia);
  await db.doc(`users/${uid}/planificador/${f}`).set({
    fecha: f, outfitId, outfitNombre: o[1], prendaIds: o[2], nota: "", actualizado: ts(ahora),
  });
}

await db.doc(`users/${uid}/colecciones/oficina`).set({
  nombre: "Ropa de oficina", descripcion: "Lunes a viernes",
  prendaIds: ["camisa-lila", "camisa-celeste", "pantalon-negro", "bolso-lila", "tenis-blancos"], fechaCreacion: ts(ahora),
});

const conversacion = db.doc(`users/${uid}/conversaciones/demo`);
await conversacion.set({ titulo: "¿Qué me pongo para la U?", fechaCreacion: ts(ahora - dia), ultimaActividad: ts(ahora - dia) });
await conversacion.collection("mensajes").doc("1").set({
  rol: "usuario", texto: "¿Qué me pongo para la U?", tieneFoto: false, fecha: ts(ahora - dia),
});
await conversacion.collection("mensajes").doc("2").set({
  rol: "asistente", rechazado: false, fecha: ts(ahora - dia + 1),
  texto: "Para la U te propongo algo cómodo y con estilo:\n- Tu **Camiseta blanca** con el **Jean azul** y los **Tenis blancos**.\n- Si hace frío, súmale la **Chaqueta negra**.\nY dale una oportunidad a tu **Bolso lila**, ¡aún no lo estrenas!",
});

console.log(`Cuenta demo lista: ${CORREO} / ${CLAVE}  (uid ${uid})`);
process.exit(0);
