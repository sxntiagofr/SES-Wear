import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../models/prenda.dart';

/// Tarjeta de una prenda en la cuadrícula del armario: foto sobre fondo blanco
/// y, si se pide, el nombre debajo.
class TarjetaPrenda extends StatelessWidget {
  const TarjetaPrenda({super.key, required this.prenda, this.onTap, this.onLongPress, this.conNombre = true});

  final Prenda prenda;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool conNombre;

  @override
  Widget build(BuildContext context) {
    final detalle = [prenda.categoria, prenda.colorPrimario].where((e) => e.isNotEmpty).join(' · ');
    return Semantics(
      button: onTap != null,
      label: prenda.nombre,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: FotoPrenda(prenda: prenda, radio: 16, margen: 8)),
            if (conNombre)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prenda.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    if (detalle.isNotEmpty)
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
