import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../outfits/data/outfits_repositorio.dart';
import '../../outfits/models/outfit.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../data/planificador_repositorio.dart';
import '../models/plan_dia.dart';

/// Planificador de atuendos (RF-07): calendario para decidir qué ponerse
/// en días futuros usando los outfits guardados.
class PlanificadorScreen extends StatefulWidget {
  const PlanificadorScreen({
    super.key,
    this.planificadorRepositorio,
    this.outfitsRepositorio,
    this.prendasRepositorio,
    this.hoy,
  });

  final PlanificadorRepositorio? planificadorRepositorio;
  final OutfitsRepositorio? outfitsRepositorio;
  final PrendasRepositorio? prendasRepositorio;

  /// Para pruebas: fecha que se toma como "hoy".
  final DateTime? hoy;

  @override
  State<PlanificadorScreen> createState() => _PlanificadorScreenState();
}

class _PlanificadorScreenState extends State<PlanificadorScreen> {
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  static const _dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late final _planRepo = widget.planificadorRepositorio ?? PlanificadorRepositorio();
  late final _outfitsRepo = widget.outfitsRepositorio ?? OutfitsRepositorio();
  late final _prendasRepo = widget.prendasRepositorio ?? PrendasRepositorio();
  late final DateTime _hoy = _soloFecha(widget.hoy ?? DateTime.now());
  late final Stream<Map<String, PlanDia>> _planes = _planRepo.observar(desde: _hoy);
  late final Stream<List<Outfit>> _outfits = _outfitsRepo.observar();
  late final Stream<List<Prenda>> _prendas = _prendasRepo.observar();

  late DateTime _mes = DateTime(_hoy.year, _hoy.month);
  late DateTime _seleccionado = _hoy;

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _intentar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      if (mounted) _avisar(exito);
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar. Revisa tu conexión.');
    }
  }

  Future<void> _asignar(List<Outfit> outfits, Map<String, Prenda> porId) async {
    if (outfits.isEmpty) {
      _avisar('Primero guarda un outfit en la pestaña Outfits.');
      return;
    }
    final elegido = await showModalBottomSheet<Outfit>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Elige un outfit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              for (final o in outfits)
                ListTile(
                  leading: MiniaturaPrenda(prenda: porId[o.prendaIds.firstOrNull], tamano: 44),
                  title: Text(o.nombre),
                  subtitle: Text('${o.prendaIds.length} prendas'),
                  trailing: o.favorito ? Icon(Icons.favorite, color: AppTheme.accent, size: 18) : null,
                  onTap: () => Navigator.pop(context, o),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null) return;
    final fecha = PlanDia.claveDe(_seleccionado);
    await _intentar(
      () => _planRepo.asignar(PlanDia(
        fecha: fecha,
        outfitId: elegido.id,
        outfitNombre: elegido.nombre,
        prendaIds: elegido.prendaIds,
      )),
      'Outfit planeado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de outfits')),
      body: StreamBuilder<List<Prenda>>(
        stream: _prendas,
        builder: (context, snapPrendas) => StreamBuilder<List<Outfit>>(
          stream: _outfits,
          builder: (context, snapOutfits) => StreamBuilder<Map<String, PlanDia>>(
            stream: _planes,
            builder: (context, snapPlanes) {
              if (snapPlanes.hasError) return const Center(child: Text('No se pudo cargar el calendario.'));
              final planes = snapPlanes.data ?? const <String, PlanDia>{};
              final porId = {for (final p in snapPrendas.data ?? const <Prenda>[]) p.id!: p};
              final plan = planes[PlanDia.claveDe(_seleccionado)];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _calendario(planes),
                  const SizedBox(height: 16),
                  _panelDia(plan, snapOutfits.data ?? const [], porId),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _calendario(Map<String, PlanDia> planes) {
    final primerDia = DateTime(_mes.year, _mes.month);
    final diasEnMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final vacios = primerDia.weekday - 1; // lunes = 0
    final puedeRetroceder = _mes.isAfter(DateTime(_hoy.year, _hoy.month));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: puedeRetroceder ? () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1)) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_meses[_mes.month - 1][0].toUpperCase()}${_meses[_mes.month - 1].substring(1)} ${_mes.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in _dias)
                  Expanded(
                    child: Center(child: Text(d, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < vacios; i++) const SizedBox.shrink(),
                for (var dia = 1; dia <= diasEnMes; dia++) _celda(DateTime(_mes.year, _mes.month, dia), planes),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _celda(DateTime dia, Map<String, PlanDia> planes) {
    final seleccionado = dia == _seleccionado;
    final esHoy = dia == _hoy;
    final pasado = dia.isBefore(_hoy);
    final tienePlan = planes.containsKey(PlanDia.claveDe(dia));
    return Semantics(
      button: true,
      selected: seleccionado,
      label: '${dia.day} de ${_meses[dia.month - 1]}${tienePlan ? ', con outfit planeado' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _seleccionado = dia),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: seleccionado ? AppTheme.primary : null,
            borderRadius: BorderRadius.circular(12),
            border: esHoy && !seleccionado ? Border.all(color: AppTheme.link) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.day}',
                style: TextStyle(
                  color: seleccionado
                      ? Colors.white
                      : pasado
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                  fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              if (tienePlan)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: seleccionado ? Colors.white : AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelDia(PlanDia? plan, List<Outfit> outfits, Map<String, Prenda> porId) {
    final titulo = _seleccionado == _hoy
        ? 'Hoy'
        : '${_seleccionado.day} de ${_meses[_seleccionado.month - 1]}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (plan == null) ...[
              Text('No hay outfit planeado para este día.', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _seleccionado.isBefore(_hoy) ? null : () => _asignar(outfits, porId),
                icon: const Icon(Icons.add),
                label: const Text('Asignar outfit'),
              ),
            ] else ...[
              Text(plan.outfitNombre.isEmpty ? 'Outfit planeado' : plan.outfitNombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final id in plan.prendaIds) MiniaturaPrenda(prenda: porId[id], tamano: 56)],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (!_seleccionado.isAfter(_hoy))
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _intentar(
                        () => _prendasRepo.registrarUso(plan.prendaIds.where(porId.containsKey)),
                        '¡Listo! Sumamos un uso a cada prenda.',
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Lo usé'),
                    ),
                  TextButton(onPressed: () => _asignar(outfits, porId), child: const Text('Cambiar')),
                  TextButton(
                    onPressed: () => _intentar(() => _planRepo.quitar(plan.fecha), 'Plan quitado.'),
                    child: const Text('Quitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
