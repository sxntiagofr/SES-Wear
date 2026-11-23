#!/usr/bin/env bash
# Configura las claves de API de SES Wear y publica el backend en Firebase (macOS / Linux).
#
# Uso, desde la carpeta raíz del proyecto (SES-Wear):
#   bash scripts/configurar-claves.sh
#
# Hace lo mismo que scripts/configurar-claves.ps1 (Windows):
#   1. Crea functions/.secret.local a partir de la plantilla (si no existe).
#   2. Revisa que las claves estén puestas.
#   3. Guarda las claves en el gestor de secretos de Firebase (no quedan en el código).
#   4. Instala las dependencias de functions/ y publica reglas y Cloud Functions.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
cd "$raiz"
archivo="functions/.secret.local"
# Solo remove.bg: la IA (Gemini) corre en la app con Firebase AI Logic y no necesita clave.
claves=(REMOVE_BG_API_KEY)

if [ ! -f "$archivo" ]; then
  cp functions/.secret.local.example "$archivo"
  echo "Se creó $archivo. Ábrelo, pega tus claves donde dice PEGA_AQUI_... y vuelve a correr este script."
  exit 1
fi

leer() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$archivo" | tail -n 1 | cut -d= -f2- \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^[\"']//" -e "s/[\"']$//" | tr -d '\r'
}

faltan=()
for nombre in "${claves[@]}"; do
  valor="$(leer "$nombre")"
  if [ -z "$valor" ] || [[ "$valor" == PEGA_AQUI* ]]; then faltan+=("$nombre"); fi
done
if [ ${#faltan[@]} -gt 0 ]; then
  echo "Faltan estas claves en $archivo: ${faltan[*]}"
  exit 1
fi
echo "Claves encontradas en $archivo."

command -v firebase >/dev/null || { echo "Instala Firebase CLI: npm install -g firebase-tools"; exit 1; }
firebase login
firebase use ses-wear

for nombre in "${claves[@]}"; do
  temporal="$(mktemp)"
  printf '%s' "$(leer "$nombre")" > "$temporal"   # sin salto de línea final
  echo "Guardando $nombre en el gestor de secretos de Firebase..."
  firebase functions:secrets:set "$nombre" --data-file "$temporal" || { rm -f "$temporal"; echo "¿El proyecto está en el plan Blaze?"; exit 1; }
  rm -f "$temporal"
done

(cd functions && npm install)
firebase deploy --only "firestore:rules,firestore:indexes,storage,functions"

echo
echo "Listo. Pasos manuales que faltan (AI Logic, App Check): ver docs/pendientes.md."
echo "Después: flutter pub get && flutter run"
