# Genera ilustraciones simples de prendas (PNG con fondo transparente) para la
# cuenta demo. Ya están generadas en scripts/demo/fotos; solo hace falta correrlo
# si se quieren cambiar.
#   powershell -ExecutionPolicy Bypass -File scripts\demo\generar-fotos.ps1

Add-Type -AssemblyName System.Drawing
$salida = Join-Path $PSScriptRoot "fotos"
New-Item -ItemType Directory -Force $salida | Out-Null

function Nuevo-Lienzo { $b = New-Object System.Drawing.Bitmap 512, 512; $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent); return @($b, $g) }
function Color($hex) { return [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Puntos($lista) { return [System.Drawing.PointF[]]($lista | ForEach-Object { New-Object System.Drawing.PointF $_[0], $_[1] }) }
function Rellenar($g, $hex, $borde, $pts) {
  $g.FillPolygon((New-Object System.Drawing.SolidBrush (Color $hex)), (Puntos $pts))
  $g.DrawPolygon((New-Object System.Drawing.Pen (Color $borde), 6), (Puntos $pts))
}
function Guardar($b, $g, $nombre) { $b.Save((Join-Path $salida "$nombre.png"), [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose() }

function Camisa($nombre, $hex, $borde, $chaqueta = $false) {
  $b, $g = Nuevo-Lienzo
  Rellenar $g $hex $borde @(@(186,60),@(326,60),@(450,130),@(410,230),@(360,200),@(360,460),@(152,460),@(152,200),@(102,230),@(62,130))
  $pen = New-Object System.Drawing.Pen (Color $borde), 6
  $g.DrawLine($pen, 256, 90, 256, 460)
  if ($chaqueta) { $g.DrawLine((New-Object System.Drawing.Pen (Color '#9E9E9E'), 4), 262, 95, 262, 455) }
  $g.FillPolygon((New-Object System.Drawing.SolidBrush (Color $borde)), (Puntos @(@(206,60),@(256,110),@(306,60))))
  Guardar $b $g $nombre
}
function Pantalon($nombre, $hex, $borde) {
  $b, $g = Nuevo-Lienzo
  Rellenar $g $hex $borde @(@(150,50),@(362,50),@(392,470),@(286,470),@(256,170),@(226,470),@(120,470))
  $g.DrawLine((New-Object System.Drawing.Pen (Color $borde), 6), 150, 95, 362, 95)
  Guardar $b $g $nombre
}
function Tenis($nombre, $hex, $borde) {
  $b, $g = Nuevo-Lienzo
  Rellenar $g $hex $borde @(@(70,300),@(90,200),@(200,190),@(280,250),@(440,280),@(460,340),@(70,340))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (Color '#BDBDBD')), 66, 340, 398, 34)
  $pen = New-Object System.Drawing.Pen (Color $borde), 5
  foreach ($x in 190, 220, 250) { $g.DrawLine($pen, $x, 215, $x + 25, 240) }
  Guardar $b $g $nombre
}
function Bolso($nombre, $hex, $borde) {
  $b, $g = Nuevo-Lienzo
  $g.DrawArc((New-Object System.Drawing.Pen (Color $borde), 14), 170, 90, 172, 180, 180, 180)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (Color $hex)), 110, 180, 292, 250)
  $g.DrawRectangle((New-Object System.Drawing.Pen (Color $borde), 6), 110, 180, 292, 250)
  Guardar $b $g $nombre
}

Camisa 'camisa-lila' '#C9A7F0' '#7E57C2'
Camisa 'camisa-celeste' '#A9D1F5' '#4A7FB5'
Camisa 'camiseta-blanca' '#FAFAFA' '#9E9E9E'
Camisa 'chaqueta-negra' '#2B2B2B' '#000000' $true
Pantalon 'jean-azul' '#4E77B5' '#2C4B7D'
Pantalon 'pantalon-negro' '#333333' '#111111'
Tenis 'tenis-blancos' '#FFFFFF' '#9E9E9E'
Bolso 'bolso-lila' '#B993E8' '#7E57C2'
Write-Host "Fotos generadas en $salida"
