import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../wardrobe/models/prenda.dart';
import '../models/outfit.dart';

/// Tarjeta de un outfit: nombre, prendas en miniatura, explicación y acciones.
class TarjetaOutfit extends StatelessWidget {
  const TarjetaOutfit({
    super.key,
    required this.outfit,
    required this.prendasPorId,
    this.acciones = const [],
    this.encabezado,
  });

  final Outfit outfit;
  final Map<String, Prenda> prendasPorId;
  final List<Widget> acciones;

  /// Widget opcional a la derecha del título (p. ej. botón de favorito).
  final Widget? encabezado;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    outfit.nombre,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                if (outfit.origen == 'ia')
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Tooltip(message: 'Sugerido por la IA', child: Icon(Icons.auto_awesome, size: 18, color: AppTheme.accent)),
                  ),
                ?encabezado,
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.prendaIds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => MiniaturaPrenda(prenda: prendasPorId[outfit.prendaIds[i]], tamano: 64),
              ),
            ),
            if (outfit.explicacion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(outfit.explicacion, style: TextStyle(color: AppTheme.textSecondary, height: 1.35)),
              ),
            ],
            if (acciones.isNotEmpty)
              Align(alignment: Alignment.centerRight, child: Wrap(children: acciones)),
          ],
        ),
      ),
    );
  }
}

/// Fila de 5 estrellas para calificar un outfit.
class Estrellas extends StatelessWidget {
  const Estrellas({super.key, required this.valor, required this.alCambiar});

  final int valor;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
            icon: Icon(i <= valor ? Icons.star_rounded : Icons.star_outline_rounded, color: AppTheme.accent),
            // Tocar la estrella actual quita la calificación.
            onPressed: () => alCambiar(i == valor ? 0 : i),
          ),
      ],
    );
  }
}
