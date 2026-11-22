// Pruebas de integración de las Cloud Functions con los emuladores de Firebase
// (Auth, Firestore, Storage y Functions de verdad, sin llamar a Gemini).
// Ejecutar:  cd test-firebase && npm install && npm test
import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { deleteApp, initializeApp } from "firebase/app";
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signOut } from "firebase/auth";
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  serverTimestamp,
  setDoc,
} from "firebase/firestore";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";
import { connectStorageEmulator, getStorage, ref, uploadBytes } from "firebase/storage";

// Puertos de firebase.pruebas.json.
const app = initializeApp({ projectId: "demo-ses-wear", apiKey: "demo", storageBucket: "demo-ses-wear.appspot.com" });
const auth = getAuth(app);
const db = getFirestore(app);
const functions = getFunctions(app);
const storage = getStorage(app);
connectAuthEmulator(auth, "http://127.0.0.1:9399", { disableWarnings: true });
connectFirestoreEmulator(db, "127.0.0.1", 8180);
connectFunctionsEmulator(functions, "127.0.0.1", 5101);
connectStorageEmulator(storage, "127.0.0.1", 9299);

const llamar = (nombre, datos) => httpsCallable(functions, nombre)(datos);
const codigo = async (promesa) => {
  try {
    await promesa;
    return "ok";
  } catch (e) {
    return e.code;
  }
};

let numero = 0;
async function nuevoUsuario() {
  numero += 1;
  const cred = await createUserWithEmailAndPassword(auth, `prueba${Date.now()}${numero}@correo.com`, "moda2026");
  return cred.user.uid;
}

const prenda = (nombre, tipo) => ({
  nombre, tipo, categoria: "", colorPrimario: "negro", colorSecundario: "", tela: "", estilo: "",
  formalidad: "casual", estacion: "todo el año", etiquetas: [], precio: null, fotoUrl: null,
  vecesUsada: 0, identificadaPorIA: false, fechaCreacion: serverTimestamp(),
});

after(async () => deleteApp(app));

describe("seguridad de las funciones", () => {
  before(async () => signOut(auth));

  test("sin sesión todas rechazan la llamada", async () => {
    for (const f of ["quitarFondo", "eliminarCuenta"]) {
      assert.equal(await codigo(llamar(f, {})), "functions/unauthenticated", f);
    }
  });
});

describe("quitarFondo: cupo diario por usuario", () => {
  test("sin API key de remove.bg responde un error claro y cuenta el uso", async () => {
    const uid = await nuevoUsuario();
    const imagen = { tipo: "image/jpeg", datos: "QUJD" };
    try {
      await llamar("quitarFondo", { imagen });
      assert.fail("debía fallar sin API key");
    } catch (e) {
      assert.equal(e.code, "functions/unavailable");
      assert.match(e.message, /remove.bg|API key/);
    }
    const uso = await getDoc(doc(db, `users/${uid}/uso`, hoyColombia()));
    assert.equal(uso.data().quitarFondo, 1);
  });

  test("bloquea al pasar el límite diario (5)", async () => {
    await nuevoUsuario();
    const imagen = { tipo: "image/jpeg", datos: "QUJD" };
    for (let i = 0; i < 5; i++) await codigo(llamar("quitarFondo", { imagen }));
    assert.equal(await codigo(llamar("quitarFondo", { imagen })), "functions/resource-exhausted");
  });
});

describe("eliminarCuenta (Ley 1581)", () => {
  test("sin la confirmación no borra nada", async () => {
    const uid = await nuevoUsuario();
    await setDoc(doc(db, `users/${uid}/prendas/p1`), prenda("Jean", "inferior"));
    assert.equal(await codigo(llamar("eliminarCuenta", {})), "functions/invalid-argument");
    assert.ok((await getDoc(doc(db, `users/${uid}/prendas/p1`))).exists());
  });

  test("borra perfil, subcolecciones, fotos y la cuenta", async () => {
    const uid = await nuevoUsuario();
    await setDoc(doc(db, `users/${uid}`), {
      email: "x@y.co", nombre: "Ana", rol: "usuario",
      consentimientoDatos: { aceptado: true, version: "1.0" },
    });
    await setDoc(doc(db, `users/${uid}/prendas/p1`), prenda("Jean", "inferior"));
    await setDoc(doc(db, `users/${uid}/outfits/o1`), {
      nombre: "Look", prendaIds: ["p1"], ocasion: "casual", clima: "cualquiera",
      explicacion: "", favorito: false, calificacion: 0, origen: "local",
    });
    await setDoc(doc(db, `users/${uid}/planificador/2026-12-01`), {
      fecha: "2026-12-01", outfitId: "o1", outfitNombre: "Look", prendaIds: ["p1"], nota: "",
    });
    await uploadBytes(ref(storage, `users/${uid}/prendas/p1.jpg`), new Uint8Array([1, 2, 3]), { contentType: "image/jpeg" });

    const r = await llamar("eliminarCuenta", { confirmacion: "ELIMINAR" });
    assert.deepEqual(r.data, { eliminada: true });

    // La cuenta ya no existe: una nueva sesión con otro usuario no ve nada y
    // los archivos ya no están. Se comprueba con un usuario nuevo + reglas,
    // y la existencia de los datos directamente en el emulador (REST).
    assert.equal(await documentosDe(uid), 0);
    assert.equal(await fotosDe(uid), 0);
    assert.equal(await existeCuenta(uid), false);
  });
});

function hoyColombia() {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Bogota" }).format(new Date());
}

// Cuenta los documentos bajo users/{uid} saltándose las reglas (token "owner" del emulador).
async function documentosDe(uid) {
  const base = "http://127.0.0.1:8180/v1/projects/demo-ses-wear/databases/(default)/documents";
  const cabeceras = { Authorization: "Bearer owner" };
  const perfil = await fetch(`${base}/users/${uid}`, { headers: cabeceras });
  let total = perfil.status === 200 ? 1 : 0;
  for (const sub of ["prendas", "outfits", "planificador", "uso"]) {
    const r = await (await fetch(`${base}/users/${uid}/${sub}`, { headers: cabeceras })).json();
    total += r.documents?.length ?? 0;
  }
  return total;
}

async function fotosDe(uid) {
  const r = await fetch(
    `http://127.0.0.1:9299/v0/b/demo-ses-wear.appspot.com/o?prefix=${encodeURIComponent(`users/${uid}/`)}`,
    { headers: { Authorization: "Bearer owner" } },
  );
  return ((await r.json()).items ?? []).length;
}

async function existeCuenta(uid) {
  const r = await fetch(
    "http://127.0.0.1:9399/identitytoolkit.googleapis.com/v1/projects/demo-ses-wear/accounts:lookup",
    {
      method: "POST",
      headers: { Authorization: "Bearer owner", "Content-Type": "application/json" },
      body: JSON.stringify({ localId: [uid] }),
    },
  );
  const datos = await r.json();
  return Array.isArray(datos.users) && datos.users.length > 0;
}
