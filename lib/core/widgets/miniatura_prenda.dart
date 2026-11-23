import 'package:material_ui/material_ui.dart';

import '../../features/wardrobe/models/prenda.dart';
import '../theme/app_theme.dart';
import '../utils/imagenes.dart';

/// Foto pequeña y cuadrada de una prenda sobre fondo blanco (como en el
/// diseño), o un ícono si no tiene foto.
class MiniaturaPrenda extends StatelessWidget {
  const MiniaturaPrenda({super.key, required this.prenda, this.tamano = 56, this.radio = 12});

  final Prenda? prenda;
  final double tamano;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: prenda?.nombre ?? 'Prenda eliminada',
      child: SizedBox.square(dimension: tamano, child: FotoPrenda(prenda: prenda, radio: radio)),
    );
  }
}

/// Foto de una prenda que llena el espacio disponible: fondo blanco y la
/// prenda completa (sin recortar), para que las que no tienen fondo se vean bien.
class FotoPrenda extends StatelessWidget {
  const FotoPrenda({super.key, required this.prenda, this.radio = 14, this.margen = 6});

  final Prenda? prenda;
  final double radio;
  final double margen;

  @override
  Widget build(BuildContext context) {
    final url = prenda?.fotoUrl;
    Widget icono([IconData i = Icons.checkroom]) => LayoutBuilder(
          builder: (_, c) => Center(
            child: Icon(prenda == null ? Icons.help_outline : i, color: AppTheme.primary, size: c.biggest.shortestSide * 0.45),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: ColoredBox(
        color: AppTheme.fondoPrenda,
        child: SizedBox.expand(
          child: url == null
              ? icono()
              : Padding(
                  padding: EdgeInsets.all(margen),
                  child: Image(
                    image: imagenDesdeUrl(url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => icono(Icons.broken_image_outlined),
                  ),
                ),
        ),
      ),
    );
  }
}
