# Configura las claves de API de SES Wear y publica el backend en Firebase (Windows).
#
# Uso, desde la carpeta raíz del proyecto (SES-Wear):
#   powershell -ExecutionPolicy Bypass -File scripts\configurar-claves.ps1
#
# Qué hace:
#   1. Crea functions\.secret.local a partir de la plantilla (si no existe) y te pide pegar las claves.
#   2. Revisa que las claves estén puestas.
#   3. Guarda las claves en el gestor de secretos de Firebase (no quedan en el código).
#   4. Instala las dependencias de functions\ y publica reglas y Cloud Functions.
#
# Requisitos: Node.js 22, Firebase CLI (npm install -g firebase-tools) y el proyecto
# de Firebase "ses-wear" en el plan Blaze.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$archivo = Join-Path $raiz "functions\.secret.local"
$plantilla = Join-Path $raiz "functions\.secret.local.example"
# Solo remove.bg: la IA (Gemini) corre en la app con Firebase AI Logic y no necesita clave.
$claves = @("REMOVE_BG_API_KEY")

function Leer-Claves {
    $valores = @{}
    foreach ($linea in Get-Content $archivo -Encoding UTF8) {
        if ($linea -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') {
            $valores[$Matches[1]] = $Matches[2].Trim('"', "'")
        }
    }
    return $valores
}

# 1. Archivo de claves
if (-not (Test-Path $archivo)) {
    Copy-Item $plantilla $archivo
    Write-Host "Se creó functions\.secret.local. Pega tus claves donde dice PEGA_AQUI_..., guarda y cierra el Bloc de notas." -ForegroundColor Yellow
    Start-Process notepad.exe $archivo -Wait
}

# 2. Validación
$valores = Leer-Claves
$faltan = $claves | Where-Object { -not $valores[$_] -or $valores[$_].StartsWith("PEGA_AQUI") }
if ($faltan) {
    Write-Host "Faltan estas claves en functions\.secret.local: $($faltan -join ', ')" -ForegroundColor Red
    Write-Host "Ábrelo, pega las claves y vuelve a correr este script."
    exit 1
}
Write-Host "Claves encontradas en functions\.secret.local." -ForegroundColor Green

# 3. Firebase
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "No se encontró Firebase CLI. Instálalo con: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}
firebase login
firebase use ses-wear
if ($LASTEXITCODE -ne 0) { exit 1 }

foreach ($nombre in $claves) {
    # Se escribe en un archivo temporal SIN salto de línea final para que la clave quede exacta.
    $temporal = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($temporal, $valores[$nombre])
        Write-Host "Guardando $nombre en el gestor de secretos de Firebase..."
        firebase functions:secrets:set $nombre --data-file $temporal
        if ($LASTEXITCODE -ne 0) { throw "No se pudo guardar $nombre. ¿El proyecto está en el plan Blaze?" }
    } finally {
        Remove-Item $temporal -Force -ErrorAction SilentlyContinue
    }
}

# 4. Dependencias y publicación
Push-Location (Join-Path $raiz "functions")
npm install
$codigoNpm = $LASTEXITCODE
Pop-Location
if ($codigoNpm -ne 0) { exit 1 }

firebase deploy --only "firestore:rules,firestore:indexes,storage,functions"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host ""
Write-Host "Listo. Pasos manuales que faltan (AI Logic, App Check): ver docs/pendientes.md." -ForegroundColor Green
Write-Host "Después: flutter pub get; flutter run"
