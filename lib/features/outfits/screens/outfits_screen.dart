import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../planner/data/planificador_repositorio.dart';
import '../../planner/models/plan_dia.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../data/outfits_repositorio.dart';
import '../models/outfit.dart';
import '../widgets/tarjeta_outfit.dart';

/// Lista de outfits guardados.
class OutfitsGuardados extends StatefulWidget {
  const OutfitsGuardados({
    super.key,
    required this.prendas,
    required this.outfitsRepositorio,
    required this.prendasRepositorio,
    this.planificadorRepositorio,
  });

  final List<Prenda> prendas;
  final OutfitsRepositorio outfitsRepositorio;
  final PrendasRepositorio prendasRepositorio;
  final PlanificadorRepositorio? planificadorRepositorio;

  @override
  State<OutfitsGuardados> createState() => _OutfitsGuardadosState();
}

class _OutfitsGuardadosState extends State<OutfitsGuardados> {
  late final Stream<List<Outfit>> _outfits = widget.outfitsRepositorio.observar();
  bool _soloFavoritos = false;

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _intentar(Future<void> Function() accion, {String? exito}) async {
    try {
      await accion();
      if (exito != null && mounted) _avisar(exito);
    } catch (_) {
      if (mounted) _avisar('No se pudo completar la acción. Revisa tu conexión.');
    }
  }

  Future<void> _planear(Outfit o) async {
    final hoy = DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Planear para el día',
    );
    if (dia == null) return;
    final repo = widget.planificadorRepositorio ?? PlanificadorRepositorio();
    await _intentar(
      () => repo.asignar(PlanDia(
        fecha: PlanDia.claveDe(dia),
        outfitId: o.id,
        outfitNombre: o.nombre,
        prendaIds: o.prendaIds,
      )),
      exito: 'Outfit planeado para el ${dia.day}/${dia.month}.',
    );
  }

  Future<void> _eliminar(Outfit o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar outfit'),
        content: Text('¿Eliminar "${o.nombre}"? Las prendas siguen en tu armario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await _intentar(() => widget.outfitsRepositorio.eliminar(o.id!));
  }

  @override
  Widget build(BuildContext context) {
    final porId = {for (final p in widget.prendas) p.id!: p};
    return StreamBuilder<List<Outfit>>(
      stream: _outfits,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('No se pudieron cargar tus outfits.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final todos = snap.data!;
        if (todos.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aún no tienes outfits guardados.\nGenera uno en la pestaña "Crear" y tócale "Guardar".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }
        final outfits = _soloFavoritos ? todos.where((o) => o.favorito).toList() : todos;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Solo favoritos'),
                selected: _soloFavoritos,
                onSelected: (v) => setState(() => _soloFavoritos = v),
              ),
            ),
            const SizedBox(height: 8),
            for (final o in outfits)
              TarjetaOutfit(
                outfit: o,
                prendasPorId: porId,
                encabezado: IconButton(
                  tooltip: o.favorito ? 'Quitar de favoritos' : 'Marcar como favorito',
                  icon: Icon(o.favorito ? Icons.favorite : Icons.favorite_border, color: AppTheme.accent),
                  onPressed: () => _intentar(() => widget.outfitsRepositorio.marcarFavorito(o.id!, !o.favorito)),
                ),
                acciones: [
                  Estrellas(
                    valor: o.calificacion,
                    alCambiar: (v) => _intentar(() => widget.outfitsRepositorio.calificar(o.id!, v)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    onSelected: (accion) => switch (accion) {
                      'usar' => _intentar(
                          () => widget.prendasRepositorio.registrarUso(o.prendaIds.where(porId.containsKey)),
                          exito: '¡Listo! Sumamos un uso a cada prenda.',
                        ),
                      'planear' => _planear(o),
                      _ => _eliminar(o),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'usar', child: Text('Lo usé hoy')),
                      PopupMenuItem(value: 'planear', child: Text('Planear para un día')),
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
