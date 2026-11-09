// Conexión del asistente con la base de datos (Cloud Firestore).
// - Lee el perfil y las prendas del armario del usuario para dárselas como contexto a Gemini.
// - Guarda cada pregunta y cada respuesta en el historial de conversaciones.
//
// Modelo de datos (ver docs/arquitectura.md):
//   users/{uid}                                      nombre, ciudad, preferencias
//   users/{uid}/prendas/{prendaId}                   nombre, tipo, categoria, colorPrimario, ...
//   users/{uid}/conversaciones/{conversacionId}      titulo, fechaCreacion, ultimaActividad
//   users/{uid}/conversaciones/{id}/mensajes/{id}    rol, texto, tieneFoto, fecha

import { FieldValue } from "firebase-admin/firestore";

// Límite de prendas que se envían a Gemini en cada mensaje, para no gastar cuota.
const MAX_PRENDAS_EN_CONTEXTO = 150;
const MAX_CARACTERES_TITULO = 60;
const ID_VALIDO = /^[A-Za-z0-9_-]{1,64}$/;

const texto = (valor) => (typeof valor === "string" ? valor.trim() : "");

// Convierte una prenda de Firestore en una línea corta y legible para la IA.
function describirPrenda(id, p) {
  const nombre = texto(p.nombre) || texto(p.categoria) || "Prenda sin nombre";
  const colores = [texto(p.colorPrimario), texto(p.colorSecundario)].filter(Boolean).join(" y ");
  const detalles = [
    texto(p.tipo),
    texto(p.categoria) !== nombre && texto(p.categoria),
    colores && `color ${colores}`,
    texto(p.tela) && `tela ${texto(p.tela)}`,
    texto(p.estilo) && `estilo ${texto(p.estilo)}`,
    texto(p.formalidad) && `formalidad ${texto(p.formalidad)}`,
    texto(p.estacion) && `para ${texto(p.estacion)}`,
    texto(p.marca) && `marca ${texto(p.marca)}`,
    Number.isFinite(p.vecesUsada) && `usada ${p.vecesUsada} ${p.vecesUsada === 1 ? "vez" : "veces"}`,
    Array.isArray(p.etiquetas) && p.etiquetas.length && `etiquetas: ${p.etiquetas.slice(0, 5).join(", ")}`,
  ].filter(Boolean);
  return `- ${nombre}${detalles.length ? ` (${detalles.join(", ")})` : ""} [id: ${id}]`;
}

// Arma el bloque de contexto con el perfil y el armario del usuario.
// Si algo falla, el asistente sigue funcionando sin contexto.
export async function cargarContextoUsuario(db, uid) {
  const usuarioRef = db.collection("users").doc(uid);
  const [perfil, prendas] = await Promise.all([
    usuarioRef.get(),
    usuarioRef.collection("prendas").limit(MAX_PRENDAS_EN_CONTEXTO).get(),
  ]);

  const lineas = [];
  const datos = perfil.exists ? perfil.data() : {};
  if (texto(datos.nombre)) lineas.push(`Nombre del usuario: ${texto(datos.nombre)}.`);
  if (texto(datos.ciudad)) lineas.push(`Ciudad: ${texto(datos.ciudad)}.`);
  if (datos.preferencias && typeof datos.preferencias === "object") {
    lineas.push(`Preferencias de estilo: ${JSON.stringify(datos.preferencias)}.`);
  } else if (texto(datos.preferencias)) {
    lineas.push(`Preferencias de estilo: ${texto(datos.preferencias)}.`);
  }

  if (prendas.empty) {
    lineas.push("ARMARIO: el usuario todavía no ha registrado prendas en la app.");
  } else {
    lineas.push(`ARMARIO DEL USUARIO (${prendas.size} prendas guardadas en la app):`);
    prendas.forEach((doc) => lineas.push(describirPrenda(doc.id, doc.data())));
    if (prendas.size === MAX_PRENDAS_EN_CONTEXTO) {
      lineas.push(`(Se muestran solo las primeras ${MAX_PRENDAS_EN_CONTEXTO} prendas.)`);
    }
  }
  return lineas.join("\n");
}

// Devuelve el último mensaje del usuario tal como se guarda en Firestore (sin la foto en base64,
// porque un documento de Firestore admite máximo 1 MB).
function ultimoMensajeDelUsuario(mensajes) {
  const m = [...mensajes].reverse().find((x) => x?.rol === "usuario") ?? {};
  return { texto: texto(m.texto), tieneFoto: Boolean(m.imagen) };
}

// Guarda la pregunta del usuario y la respuesta del asistente.
// Si no llega `conversacionId`, se crea una conversación nueva. Devuelve el id usado.
export async function guardarIntercambio(db, uid, { conversacionId, mensajes, respuesta }) {
  const conversaciones = db.collection("users").doc(uid).collection("conversaciones");
  const usuario = ultimoMensajeDelUsuario(mensajes);

  const existe = typeof conversacionId === "string" && ID_VALIDO.test(conversacionId);
  const conversacionRef = existe ? conversaciones.doc(conversacionId) : conversaciones.doc();
  const ahora = FieldValue.serverTimestamp();

  const lote = db.batch();
  if (existe) {
    lote.set(conversacionRef, { ultimaActividad: ahora }, { merge: true });
  } else {
    const titulo = (usuario.texto || "Foto de una prenda").slice(0, MAX_CARACTERES_TITULO);
    lote.set(conversacionRef, { titulo, fechaCreacion: ahora, ultimaActividad: ahora });
  }

  // Dos marcas de tiempo distintas para que el orden por fecha sea siempre usuario → asistente.
  const fechaUsuario = new Date();
  const fechaAsistente = new Date(fechaUsuario.getTime() + 1);
  const mensajesRef = conversacionRef.collection("mensajes");
  lote.set(mensajesRef.doc(), {
    rol: "usuario",
    texto: usuario.texto,
    tieneFoto: usuario.tieneFoto,
    fecha: fechaUsuario,
  });
  lote.set(mensajesRef.doc(), {
    rol: "asistente",
    texto: respuesta.texto,
    rechazado: Boolean(respuesta.rechazado),
    fecha: fechaAsistente,
  });
  await lote.commit();
  return conversacionRef.id;
}
