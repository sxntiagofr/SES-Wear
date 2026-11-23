import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

/// Foto lista para guardar: bytes y tipo (image/png o image/jpeg).
class FotoComprimida {
  const FotoComprimida(this.bytes, this.tipo);
  final Uint8List bytes;
  final String tipo;

  /// `data:image/...;base64,...` para guardarla dentro de Firestore.
  String get comoDataUrl => 'data:$tipo;base64,${base64Encode(bytes)}';
}

/// Reduce la foto para guardarla en la base de datos (un documento de
/// Firestore admite máximo 1 MB). Las fotos sin fondo (PNG con transparencia)
/// se guardan en PNG; las demás en JPEG.
FotoComprimida comprimirFoto(Uint8List original, {required String tipo, int ladoMaximo = 640}) {
  final imagen = img.decodeImage(original);
  if (imagen == null) return FotoComprimida(original, tipo);
  var reducida = imagen;
  final lado = imagen.width > imagen.height ? imagen.width : imagen.height;
  if (lado > ladoMaximo) {
    reducida = imagen.width >= imagen.height
        ? img.copyResize(imagen, width: ladoMaximo, interpolation: img.Interpolation.average)
        : img.copyResize(imagen, height: ladoMaximo, interpolation: img.Interpolation.average);
  }
  final transparente = reducida.hasAlpha && tipo == 'image/png';
  if (transparente) {
    var png = Uint8List.fromList(img.encodePng(reducida, level: 9));
    // Si aún es grande, se reduce un poco más.
    if (png.length > 700000) {
      png = Uint8List.fromList(img.encodePng(img.copyResize(reducida, width: reducida.width * 2 ~/ 3), level: 9));
    }
    return FotoComprimida(png, 'image/png');
  }
  return FotoComprimida(Uint8List.fromList(img.encodeJpg(reducida, quality: 82)), 'image/jpeg');
}

/// Imagen de una prenda: la foto puede estar en Storage (URL https) o dentro
/// de Firestore (`data:image/...;base64,...`).
ImageProvider imagenDesdeUrl(String url) {
  if (!url.startsWith('data:')) return NetworkImage(url);
  // Se reutiliza el mismo MemoryImage para no decodificar la foto en cada redibujo.
  final guardada = _cache.remove(url);
  final imagen = guardada ?? MemoryImage(UriData.parse(url).contentAsBytes());
  _cache[url] = imagen;
  if (_cache.length > 150) _cache.remove(_cache.keys.first);
  return imagen;
}

final _cache = <String, MemoryImage>{};
