import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/prenda.dart';

/// Tarjeta de una prenda en la cuadrícula del armario.
class TarjetaPrenda extends StatelessWidget {
  const TarjetaPrenda({super.key, required this.prenda, this.onLongPress});

  final Prenda prenda;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final detalle = [prenda.categoria, prenda.colorPrimario].where((e) => e.isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: prenda.fotoUrl == null
                  ? const ColoredBox(
                      color: AppTheme.primaryLight,
                      child: Icon(Icons.checkroom, color: AppTheme.primary, size: 40),
                    )
                  : Image.network(
                      prenda.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppTheme.primaryLight,
                        child: Icon(Icons.broken_image_outlined, color: AppTheme.primary),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prenda.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  if (detalle.isNotEmpty)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
