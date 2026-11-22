import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Botón principal con el degradado rosa → lila del diseño de SES Wear.
class BotonDegradado extends StatelessWidget {
  const BotonDegradado({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.alto = 52,
    this.cargando = false,
    this.tamanoTexto = 17,
  });

  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final double alto;
  final bool cargando;
  final double tamanoTexto;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return Semantics(
      button: true,
      enabled: activo,
      label: texto,
      excludeSemantics: true,
      child: Opacity(
        opacity: activo || cargando ? 1 : 0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.degradado,
            borderRadius: BorderRadius.circular(alto / 2),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(alto / 2),
              onTap: activo ? onPressed : null,
              child: SizedBox(
                height: alto,
                child: Center(
                  child: cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              texto,
                              style: TextStyle(color: Colors.white, fontSize: tamanoTexto, fontWeight: FontWeight.w700),
                            ),
                            if (icono != null) ...[
                              const SizedBox(width: 10),
                              Icon(icono, color: Colors.white, size: tamanoTexto + 5),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario con borde lila (p. ej. "Añadir a favoritos").
class BotonContorno extends StatelessWidget {
  const BotonContorno({super.key, required this.texto, required this.onPressed, this.icono, this.alto = 48});

  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icono == null ? const SizedBox.shrink() : Icon(icono, size: 20),
      label: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(alto),
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: Color(0xFF9470F2), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(alto / 2)),
      ),
    );
  }
}
