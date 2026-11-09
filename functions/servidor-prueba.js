// Servidor local para probar el chatbot en el navegador, sin Firebase ni Flutter.
// Uso: npm run prueba  →  abre http://localhost:3000

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const aqui = path.dirname(fileURLToPath(import.meta.url));

// La API key se lee de functions/.secret.local (no se sube a git).
// Es el mismo archivo que usa el emulador de Firebase.
try {
  process.loadEnvFile(path.join(aqui, ".secret.local"));
} catch {
  // Si no existe, se avisa al usuario cuando intente chatear.
}

const { responder, describirError, MODELOS } = await import("./src/asistente.js");
const { identificarPrenda } = await import("./src/identificador.js");

const PUERTO = Number(process.env.PORT) || 3000;
const PAGINA = path.join(aqui, "prueba", "index.html");

function leerCuerpo(req) {
  return new Promise((resolve, reject) => {
    let datos = "";
    req.on("data", (parte) => {
      datos += parte;
      // El historial puede incluir varias fotos en base64.
      if (datos.length > 20_000_000) reject(new Error("Solicitud demasiado grande"));
    });
    req.on("end", () => resolve(datos));
    req.on("error", reject);
  });
}

async function atenderChat(req, res) {
  if (!process.env.GEMINI_API_KEY) {
    res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ error: "Falta la API key. Crea functions/.secret.local a partir de .secret.local.example." }));
    return;
  }

  let mensajes;
  try {
    mensajes = JSON.parse(await leerCuerpo(req)).mensajes;
  } catch {
    res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ error: "Solicitud inválida." }));
    return;
  }

  // La respuesta se envía como líneas JSON: {"t": "..."} por cada fragmento
  // y al final {"fin": true, "texto": "..."} con el texto completo.
  res.writeHead(200, { "Content-Type": "application/x-ndjson; charset=utf-8", "Cache-Control": "no-store" });
  const enviar = (obj) => res.write(JSON.stringify(obj) + "\n");

  try {
    const { texto } = await responder(mensajes, {
      apiKey: process.env.GEMINI_API_KEY,
      alTexto: (t) => enviar({ t }),
    });
    enviar({ fin: true, texto });
  } catch (error) {
    const { mensaje } = describirError(error);
    console.error("[chat]", error?.message ?? error);
    enviar({ error: mensaje });
  }
  res.end();
}

const servidor = http.createServer(async (req, res) => {
  if (req.method === "GET" && (req.url === "/" || req.url === "/index.html")) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    fs.createReadStream(PAGINA).pipe(res);
    return;
  }
  if (req.method === "POST" && req.url === "/api/identificar") {
    // Prueba de la identificación de prendas: body { "imagen": { "tipo", "datos" } }.
    try {
      if (!process.env.GEMINI_API_KEY) throw new Error("Falta la API key en functions/.secret.local");
      const { imagen } = JSON.parse(await leerCuerpo(req));
      const prenda = await identificarPrenda(imagen, { apiKey: process.env.GEMINI_API_KEY });
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify(prenda));
    } catch (error) {
      console.error("[identificar]", error?.message ?? error);
      res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ error: describirError(error).mensaje }));
    }
    return;
  }
  if (req.method === "POST" && req.url === "/api/chat") {
    await atenderChat(req, res);
    return;
  }
  res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("No encontrado");
});

servidor.listen(PUERTO, "127.0.0.1", () => {
  console.log(`Chat de prueba de SES Wear en http://localhost:${PUERTO}`);
  console.log(`Modelos: ${MODELOS.join(", ")}`);
  if (!process.env.GEMINI_API_KEY) {
    console.log("Aviso: falta la API key en functions/.secret.local");
  }
});
