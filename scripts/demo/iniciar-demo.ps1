# Abre SES Wear con una cuenta demo llena de datos, usando los EMULADORES de
# Firebase (no toca el proyecto real). Desde la carpeta SES-Wear:
#   powershell -ExecutionPolicy Bypass -File scripts\demo\iniciar-demo.ps1
#
# Cuenta: demo@seswear.co  /  moda2026
# Requisitos: Flutter, Node 22, Firebase CLI, Java 21 y `npm install` en functions/.
# La IA (asistente, identificar prendas) usa el proyecto real con Firebase AI Logic.

$ErrorActionPreference = "Stop"
$raiz = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $raiz

Write-Host "1/3 Iniciando los emuladores de Firebase (ventana aparte)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$raiz'; firebase emulators:start --only auth,firestore,storage --project ses-wear"

$listo = $false
for ($i = 0; $i -lt 90; $i++) {
  try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:9099/" -TimeoutSec 2 | Out-Null; Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8080/" -TimeoutSec 2 | Out-Null; $listo = $true; break } catch { Start-Sleep -Seconds 2 }
}
if (-not $listo) { throw "Los emuladores no arrancaron. Revisa la otra ventana (¿Java 21 instalado? ¿puerto 8080 libre?)." }
Start-Sleep -Seconds 3

Write-Host "2/3 Creando la cuenta demo..." -ForegroundColor Cyan
node scripts\demo\sembrar-demo.mjs

Write-Host "3/3 Abriendo la app en Chrome..." -ForegroundColor Cyan
Write-Host "Inicia sesión con demo@seswear.co / moda2026" -ForegroundColor Green
flutter run -d chrome --dart-define=USAR_EMULADORES=true
