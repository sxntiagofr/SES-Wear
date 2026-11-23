// Pruebas de las reglas de seguridad con los emuladores de Firebase.
// Ejecutar:  cd test-firebase && npm install && npm test
// Los documentos de prueba tienen la misma forma que los que escribe la app.
import { after, before, beforeEach, describe, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { ref, uploadBytes } from "firebase/storage";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-ses-wear",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
    storage: { rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8") },
  });
});

after(async () => env?.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
});

const ana = () => env.authenticatedContext("ana").firestore();
const luis = () => env.authenticatedContext("luis").firestore();

// Como Prenda.aFirestore() + fechaCreacion (prendas_repositorio.dart).
const prenda = (extra = {}) => ({
  nombre: "Jean azul",
  tipo: "inferior",
  categoria: "jean",
  colorPrimario: "azul",
  colorSecundario: "",
  tela: "denim",
  estilo: "clásico",
  formalidad: "casual",
  estacion: "todo el año",
  etiquetas: ["tiro alto"],
  precio: null,
  fotoUrl: "https://firebasestorage.googleapis.com/x.jpg",
  vecesUsada: 0,
  identificadaPorIA: true,
  fechaCreacion: serverTimestamp(),
  ...extra,
});

// Como PerfilUsuario.aFirestoreNuevo().
const perfil = (extra = {}) => ({
  email: "ana@correo.com",
  nombre: "Ana",
  apellido: "Gómez",
  telefono: "3001234567",
  ciudad: "",
  fotoUrl: null,
  proveedor: "password",
  rol: "usuario",
  locale: "es-CO",
  preferencias: { estilos: [], colores: [], ocasiones: [] },
  consentimientoDatos: { aceptado: true, fecha: serverTimestamp(), version: "1.0" },
  fechaRegistro: serverTimestamp(),
  ultimoAcceso: serverTimestamp(),
  ...extra,
});

describe("perfil users/{uid}", () => {
  test("el dueño crea su perfil como usuario", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana"), perfil()));
  });
  test("nadie se crea como admin", async () => {
    await assertFails(setDoc(doc(ana(), "users/ana"), perfil({ rol: "admin" })));
  });
  test("otro usuario no puede leerlo", async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), "users/ana"), { nombre: "Ana" }));
    await assertFails(getDoc(doc(luis(), "users/ana")));
  });
  test("editar perfil (merge) funciona y no permite cambiar el rol", async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), "users/ana"), { nombre: "Ana", rol: "usuario" }));
    await assertSucceeds(setDoc(doc(ana(), "users/ana"), {
      nombre: "Ana", apellido: "G", telefono: "300", ciudad: "Bogotá",
      preferencias: { estilos: ["urbano"], colores: [], ocasiones: ["trabajo"] },
    }, { merge: true }));
    await assertFails(setDoc(doc(ana(), "users/ana"), { rol: "admin" }, { merge: true }));
  });
});

describe("prendas", () => {
  test("guardar una prenda como lo hace la app", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana/prendas/p1"), prenda()));
  });
  test("con precio y sin foto también", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana/prendas/p1"), prenda({ precio: 120000, fotoUrl: null })));
  });
  test("datos mal formados se rechazan", async () => {
    for (const malo of [
      { nombre: "" },
      { tipo: "zapato" },
      { fotoUrl: 123 },
      { vecesUsada: "2" },
      { estacion: "otoño" },
      { campoRaro: true },
      { precio: -5 },
    ]) {
      await assertFails(setDoc(doc(ana(), "users/ana/prendas/p1"), prenda(malo)), JSON.stringify(malo));
    }
  });
  test('"La usé hoy" (increment + ultimoUso) y editar funcionan', async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), "users/ana/prendas/p1"), prenda({ fechaCreacion: new Date() })));
    await assertSucceeds(updateDoc(doc(ana(), "users/ana/prendas/p1"), {
      vecesUsada: increment(1),
      ultimoUso: serverTimestamp(),
    }));
    // Como Prenda.aFirestoreEditable().
    await assertSucceeds(updateDoc(doc(ana(), "users/ana/prendas/p1"), {
      nombre: "Jean favorito", tipo: "inferior", categoria: "jean", colorPrimario: "azul",
      colorSecundario: "", tela: "denim", estilo: "", formalidad: "casual",
      estacion: "todo el año", etiquetas: [], precio: 99000,
    }));
  });
  test("otro usuario no puede leer ni escribir mis prendas", async () => {
    await assertFails(getDoc(doc(luis(), "users/ana/prendas/p1")));
    await assertFails(setDoc(doc(luis(), "users/ana/prendas/p1"), prenda()));
  });
  test("eliminar la propia prenda", async () => {
    await assertSucceeds(deleteDoc(doc(ana(), "users/ana/prendas/p1")));
  });
});

describe("outfits, colecciones y planificador", () => {
  const outfit = (extra = {}) => ({
    nombre: "Look casual en azul",
    prendaIds: ["p1", "p2"],
    ocasion: "casual",
    clima: "cualquiera",
    explicacion: "Combina.",
    favorito: false,
    calificacion: 0,
    origen: "local",
    fechaCreacion: serverTimestamp(),
    ...extra,
  });

  test("guardar, marcar favorito y calificar un outfit", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana/outfits/o1"), outfit()));
    await assertSucceeds(updateDoc(doc(ana(), "users/ana/outfits/o1"), { favorito: true }));
    await assertSucceeds(updateDoc(doc(ana(), "users/ana/outfits/o1"), { calificacion: 5 }));
  });
  test("outfits inválidos se rechazan", async () => {
    await assertFails(setDoc(doc(ana(), "users/ana/outfits/o1"), outfit({ calificacion: 6 })));
    await assertFails(setDoc(doc(ana(), "users/ana/outfits/o1"), outfit({ prendaIds: [] })));
    await assertFails(setDoc(doc(ana(), "users/ana/outfits/o1"), outfit({ origen: "hack" })));
  });
  test("colecciones", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana/colecciones/c1"), {
      nombre: "Oficina", descripcion: "", prendaIds: [], fechaCreacion: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(ana(), "users/ana/colecciones/c1"), {
      nombre: "Oficina", descripcion: "Lunes a viernes", prendaIds: ["p1"],
    }));
    await assertFails(setDoc(doc(ana(), "users/ana/colecciones/c2"), { nombre: "", prendaIds: [] }));
  });
  test("planificador: el id debe ser la fecha", async () => {
    const plan = (fecha) => ({
      fecha, outfitId: "o1", outfitNombre: "Look", prendaIds: ["p1"], nota: "", actualizado: serverTimestamp(),
    });
    await assertSucceeds(setDoc(doc(ana(), "users/ana/planificador/2026-11-25"), plan("2026-11-25")));
    await assertFails(setDoc(doc(ana(), "users/ana/planificador/2026-11-25"), plan("2026-11-26")));
    await assertFails(setDoc(doc(ana(), "users/ana/planificador/mañana"), plan("mañana")));
    await assertSucceeds(deleteDoc(doc(ana(), "users/ana/planificador/2026-11-25")));
  });
});

describe("historial del asistente y datos del servidor", () => {
  test("conversaciones: la app guarda el historial del asistente con datos válidos", async () => {
    await assertSucceeds(setDoc(doc(ana(), "users/ana/conversaciones/c1"), {
      titulo: "¿Qué me pongo?", fechaCreacion: serverTimestamp(), ultimaActividad: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(ana(), "users/ana/conversaciones/c1/mensajes/m1"), {
      rol: "usuario", texto: "¿Qué me pongo?", tieneFoto: false, fecha: new Date(),
    }));
    await assertSucceeds(setDoc(doc(ana(), "users/ana/conversaciones/c1/mensajes/m2"), {
      rol: "asistente", texto: "Un jean.", rechazado: false, fecha: new Date(),
    }));
    await assertFails(setDoc(doc(ana(), "users/ana/conversaciones/c1/mensajes/m3"), { rol: "sistema", texto: "x", fecha: new Date() }));
    await assertFails(setDoc(doc(ana(), "users/ana/conversaciones/c1/mensajes/m4"), { rol: "usuario", texto: "x".repeat(8001), fecha: new Date() }));
    await assertFails(setDoc(doc(ana(), "users/ana/conversaciones/c1"), { titulo: "x", raro: 1 }));
    await assertFails(getDoc(doc(luis(), "users/ana/conversaciones/c1/mensajes/m1")));
    await assertFails(setDoc(doc(luis(), "users/ana/conversaciones/c2"), { titulo: "x" }));
  });
  test("contador de uso de IA: solo lectura", async () => {
    await assertSucceeds(getDoc(doc(ana(), "users/ana/uso/2026-11-21")));
    await assertFails(setDoc(doc(ana(), "users/ana/uso/2026-11-21"), { chat: 0 }));
  });
  test("colecciones desconocidas están bloqueadas", async () => {
    await assertFails(setDoc(doc(ana(), "users/ana/otra/x"), { a: 1 }));
    await assertFails(setDoc(doc(ana(), "global/x"), { a: 1 }));
  });
});

describe("storage", () => {
  const foto = new Uint8Array([0xff, 0xd8, 0xff]);
  test("el dueño sube fotos de sus prendas", async () => {
    const s = env.authenticatedContext("ana").storage();
    await assertSucceeds(uploadBytes(ref(s, "users/ana/prendas/p1.jpg"), foto, { contentType: "image/jpeg" }));
  });
  test("no se aceptan archivos que no son imágenes ni fotos en carpetas ajenas", async () => {
    const s = env.authenticatedContext("ana").storage();
    await assertFails(uploadBytes(ref(s, "users/ana/prendas/x.txt"), foto, { contentType: "text/plain" }));
    await assertFails(uploadBytes(ref(s, "users/luis/prendas/p1.jpg"), foto, { contentType: "image/jpeg" }));
  });
});
