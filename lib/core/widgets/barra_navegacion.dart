import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Barra inferior del diseño de referencia: Inicio, Crear, Cámara (botón
/// central elevado), Calendario y Perfil. La cámara es una acción, no una pestaña.
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({super.key, required this.actual, required this.alElegir, required this.alCamara});

  /// Pestaña activa: 0 Inicio, 1 Crear, 2 Calendario, 3 Perfil.
  final int actual;
  final ValueChanged<int> alElegir;
  final VoidCallback alCamara;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Item(icono: Icons.home_outlined, activo: Icons.home, texto: 'Inicio', seleccionado: actual == 0, onTap: () => alElegir(0)),
              _Item(icono: Icons.checkroom_outlined, activo: Icons.checkroom, texto: 'Crear', seleccionado: actual == 1, onTap: () => alElegir(1)),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Cámara: agregar prenda',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: alCamara,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.degradado,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.photo_camera, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 2),
                        Text('Cámara', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
              _Item(
                icono: Icons.calendar_month_outlined,
                activo: Icons.calendar_month,
                texto: 'Calendario',
                seleccionado: actual == 2,
                onTap: () => alElegir(2),
              ),
              _Item(icono: Icons.person_outline, activo: Icons.person, texto: 'Perfil', seleccionado: actual == 3, onTap: () => alElegir(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icono,
    required this.activo,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icono;
  final IconData activo;
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? AppTheme.link : AppTheme.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: seleccionado,
        label: texto,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: seleccionado ? AppTheme.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(seleccionado ? activo : icono, color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(
                texto,
                style: TextStyle(fontSize: 11, color: color, fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
