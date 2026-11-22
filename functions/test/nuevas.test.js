// Tests de las funciones nuevas: límite diario, generador de outfits y eliminación de cuenta.
import { test } from "node:test";
import assert from "node:assert/strict";
import { ErrorDeEntrada } from "../src/asistente.js";
import { consumirCupo, ErrorDeLimite, fechaColombia } from "../src/limites.js";
import { validarSolicitud, normalizarOutfits, describirPrendas, generarOutfits } from "../src/outfits.js";
import { eliminarDatosDeUsuario } from "../src/cuenta.js";

// ---------- limites.js ----------
function dbConContador() {
  const datos = new Map();
  const ref = (ruta) => ({ ruta, collection: (c) => col(`${ruta}/${c}`) });
  const col = (ruta) => ({ doc: (id) => ref(`${ruta}/${id}`) });
  return {
    datos,
    collection: col,
    runTransaction: async (fn) =>
      fn({
        get: async (r) => ({ exists: datos.has(r.ruta), data: () => datos.get(r.ruta) }),
        set: (r, valor) => datos.set(r.ruta, { ...(datos.get(r.ruta) ?? {}), ...valor }),
      }),
  };
}

test("límite: la fecha usa la hora de Colombia", () => {
  // 3 a. m. UTC del 22 = 10 p. m. del 21 en Colombia.
  assert.equal(fechaColombia(new Date("2026-11-22T03:00:00Z")), "2026-11-21");
});

test("límite: cuenta los usos y bloquea al llegar al tope", async () => {
  const db = dbConContador();
  const ahora = new Date("2026-11-21T15:00:00Z");
  const limites = { chat: 2 };
  await consumirCupo(db, "u1", "chat", { ahora, limites });
  await consumirCupo(db, "u1", "chat", { ahora, limites });
  await assert.rejects(consumirCupo(db, "u1", "chat", { ahora, limites }), ErrorDeLimite);
  assert.equal(db.datos.get("users/u1/uso/2026-11-21").chat, 2);
});

test("límite: al día siguiente el cupo se renueva y es por usuario", async () => {
  const db = dbConContador();
  const limites = { chat: 1 };
  await consumirCupo(db, "u1", "chat", { ahora: new Date("2026-11-21T15:00:00Z"), limites });
  await consumirCupo(db, "u1", "chat", { ahora: new Date("2026-11-22T15:00:00Z"), limites });
  await consumirCupo(db, "u2", "chat", { ahora: new Date("2026-11-21T15:00:00Z"), limites });
});

// ---------- outfits.js ----------
test("outfits: valida ocasión y normaliza el resto", () => {
  assert.throws(() => validarSolicitud({ ocasion: "boda" }), ErrorDeEntrada);
  const s = validarSolicitud({ ocasion: "trabajo", clima: "nieve", cantidad: 99, excluir: [["a", 3, "b"], "x"] });
  assert.deepEqual(s, { ocasion: "trabajo", clima: "cualquiera", cantidad: 5, excluir: [["a", "b"]], coleccionId: null });
  assert.equal(validarSolicitud({ ocasion: "casual", coleccionId: "../x" }).coleccionId, null);
});

test("outfits: descarta ids inventados, repetidos y combinaciones ya mostradas", () => {
  const r = normalizarOutfits(
    {
      outfits: [
        { nombre: "A", prendaIds: ["p1", "p2", "p2"], explicacion: "ok" },
        { nombre: "B", prendaIds: ["p1", "inventada"], explicacion: "" },
        { nombre: "C", prendaIds: ["p2", "p1"], explicacion: "repetido de A" },
        { nombre: "D", prendaIds: ["p3", "p1"], explicacion: "ya mostrado" },
        { nombre: "", prendaIds: ["p2", "p3"] },
      ],
    },
    ["p1", "p2", "p3"],
    [["p1", "p3"]],
  );
  assert.deepEqual(r.map((o) => o.prendaIds), [["p1", "p2"], ["p2", "p3"]]);
  assert.equal(r[1].nombre, "Outfit sugerido");
});

test("outfits: respuesta mal formada → lista vacía", () => {
  assert.deepEqual(normalizarOutfits(null, ["p1"]), []);
  assert.deepEqual(normalizarOutfits({ outfits: "x" }, ["p1"]), []);
});

test("outfits: describe las prendas con su id para la IA", () => {
  const t = describirPrendas([{ id: "p1", nombre: "Jean", tipo: "inferior", colorPrimario: "azul", vecesUsada: 2 }]);
  assert.equal(t, "- id p1: Jean (inferior, azul, usada 2)");
});

test("outfits: con menos de 2 prendas avisa sin llamar a Gemini", async () => {
  await assert.rejects(
    generarOutfits({ prendas: [{ id: "p1" }], ocasion: "casual", clima: "calor", cantidad: 3, excluir: [] }, { apiKey: "k" }),
    ErrorDeEntrada,
  );
});

// ---------- cuenta.js ----------
test("cuenta: borra Firestore recursivo, fotos y la cuenta, en ese orden", async () => {
  const pasos = [];
  await eliminarDatosDeUsuario(
    {
      db: {
        collection: (c) => ({ doc: (id) => `${c}/${id}` }),
        recursiveDelete: async (ref) => pasos.push(`firestore:${ref}`),
      },
      bucket: { deleteFiles: async ({ prefix }) => pasos.push(`storage:${prefix}`) },
      auth: { deleteUser: async (uid) => pasos.push(`auth:${uid}`) },
      logger: { warn: () => {} },
    },
    "u1",
  );
  assert.deepEqual(pasos, ["firestore:users/u1", "storage:users/u1/", "auth:u1"]);
});

test("cuenta: si fallan las fotos igual borra la cuenta", async () => {
  let borrada = false;
  await eliminarDatosDeUsuario(
    {
      db: { collection: () => ({ doc: () => "x" }), recursiveDelete: async () => {} },
      bucket: { deleteFiles: async () => { throw new Error("bucket"); } },
      auth: { deleteUser: async () => { borrada = true; } },
      logger: { warn: () => {} },
    },
    "u1",
  );
  assert.ok(borrada);
});
