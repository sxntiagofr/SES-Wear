import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../planner/data/planificador_repositorio.dart';
import '../../planner/models/plan_dia.dart';
import '../../planner/screens/planificador_screen.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../data/outfits_repositorio.dart';
import '../models/outfit.dart';
import '../widgets/tarjeta_outfit.dart';
import 'outfits_screen.dart';

/// Pestaña Calendario (RF-03 y RF-07, diseño de referencia): "Ideas del Día"
/// con la semana planeada y "Conjuntos guardados".
class MisOutfitsScreen extends StatefulWidget {
  const MisOutfitsScreen({
    super.key,
    this.prendasRepositorio,
    this.outfitsRepositorio,
    this.planificadorRepositorio,
    this.hoy,
  });

  final PrendasRepositorio? prendasRepositorio;
  final OutfitsRepositorio? outfitsRepositorio;
  final PlanificadorRepositorio? planificadorRepositorio;

  /// Para pruebas: fecha que se toma como "hoy".
  final DateTime? hoy;

  @override
  State<MisOutfitsScreen> createState() => _MisOutfitsScreenState();
}

class _MisOutfitsScreenState extends State<MisOutfitsScreen> {
  static const _dias = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  late final _prendasRepo = widget.prendasRepositorio ?? PrendasRepositorio();
  late final _outfitsRepo = widget.outfitsRepositorio ?? OutfitsRepositorio();
  late final _planRepo = widget.planificadorRepositorio ?? PlanificadorRepositorio();
  late final DateTime _hoy = _soloFecha(widget.hoy ?? DateTime.now());
  late final Stream<List<Prenda>> _prendas = _prendasRepo.observar();
  late final Stream<List<Outfit>> _outfits = _outfitsRepo.observar();
  late final Stream<Map<String, PlanDia>> _planes = _planRepo.observar(desde: _hoy);

  /// Lunes de la semana que se muestra.
  late DateTime _lunes = _hoy.subtract(Duration(days: _hoy.weekday - 1));

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _intentar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      if (mounted) _avisar(exito);
    } catch (_) {
      if (mounted) _avisar('No se pudo completar la acción. Revisa tu conexión.');
    }
  }

  Future<void> _planear(Outfit o, DateTime dia) => _intentar(
        () => _planRepo.asignar(PlanDia(
          fecha: PlanDia.claveDe(dia),
          outfitId: o.id,
          outfitNombre: o.nombre,
          prendaIds: o.prendaIds,
        )),
        '"${o.nombre}" quedó para el ${dia.day} de ${_meses[dia.month - 1]}.',
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prenda>>(
      stream: _prendas,
      builder: (context, snapPrendas) => StreamBuilder<List<Outfit>>(
        stream: _outfits,
        builder: (context, snapOutfits) => StreamBuilder<Map<String, PlanDia>>(
          stream: _planes,
          builder: (context, snapPlanes) {
            final porId = {for (final p in snapPrendas.data ?? const <Prenda>[]) p.id!: p};
            final outfits = snapOutfits.data ?? const <Outfit>[];
            final planes = snapPlanes.data ?? const <String, PlanDia>{};
            return Scaffold(
              appBar: AppBar(
                title: const Text('Mis Outfits'),
                actions: [
                  IconButton(
                    tooltip: 'Calendario del mes',
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlanificadorScreen(
                        planificadorRepositorio: _planRepo,
                        outfitsRepositorio: _outfitsRepo,
                        prendasRepositorio: _prendasRepo,
                      ),
                    )),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _encabezadoSemana(),
                  const SizedBox(height: 10),
                  _semana(planes, porId, outfits),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Conjuntos guardados',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ),
                      IconButton(
                        tooltip: 'Ver todos los conjuntos',
                        icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Conjuntos guardados')),
                            body: OutfitsGuardados(
                              prendas: porId.values.toList(),
                              outfitsRepositorio: _outfitsRepo,
                              prendasRepositorio: _prendasRepo,
                              planificadorRepositorio: _planRepo,
                            ),
                          ),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _conjuntos(outfits, porId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _encabezadoSemana() {
    final domingo = _lunes.add(const Duration(days: 6));
    final rango = _lunes.month == domingo.month
        ? '${_lunes.day} al ${domingo.day} de ${_meses[domingo.month - 1]}'
        : '${_lunes.day} ${_meses[_lunes.month - 1]} al ${domingo.day} ${_meses[domingo.month - 1]}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ideas del Día',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              Text(rango, style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Semana anterior',
          onPressed: () => setState(() => _lunes = _lunes.subtract(const Duration(days: 7))),
          icon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
        ),
        IconButton(
          tooltip: 'Semana siguiente',
          onPressed: () => setState(() => _lunes = _lunes.add(const Duration(days: 7))),
          icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _semana(Map<String, PlanDia> planes, Map<String, Prenda> porId, List<Outfit> outfits) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(child: _columnaDia(_lunes.add(Duration(days: i)), i, planes, porId, outfits)),
        ],
      ),
    );
  }

  Widget _columnaDia(
      DateTime dia, int indice, Map<String, PlanDia> planes, Map<String, Prenda> porId, List<Outfit> outfits) {
    final plan = planes[PlanDia.claveDe(dia)];
    final esHoy = dia == _hoy;
    return Semantics(
      button: true,
      label: '${_dias[indice]} ${dia.day}${plan == null ? ', sin outfit' : ', ${plan.outfitNombre}'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _abrirDia(dia, plan, porId, outfits),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.fromLTRB(3, 6, 3, 6),
          constraints: const BoxConstraints(minHeight: 190),
          decoration: BoxDecoration(
            color: esHoy ? AppTheme.primaryLight : AppTheme.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: esHoy ? Border.all(color: AppTheme.link, width: 1.4) : null,
          ),
          child: Column(
            children: [
              Text(_dias[indice],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('${dia.day}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              if (plan != null) ...[
                for (final id in plan.prendaIds.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AspectRatio(aspectRatio: 1, child: FotoPrenda(prenda: porId[id], radio: 8, margen: 2)),
                  ),
                if (plan.prendaIds.length > 3)
                  Text('+${plan.prendaIds.length - 3}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Icon(Icons.add, size: 18, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirDia(DateTime dia, PlanDia? plan, Map<String, Prenda> porId, List<Outfit> outfits) async {
    final titulo = dia == _hoy ? 'Hoy' : '${_dias[dia.weekday - 1]} ${dia.day} de ${_meses[dia.month - 1]}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (hoja) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(hoja).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              if (plan != null) ...[
                Text(plan.outfitNombre.isEmpty ? 'Outfit planeado' : plan.outfitNombre,
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final id in plan.prendaIds) MiniaturaPrenda(prenda: porId[id], tamano: 64),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  if (!dia.isAfter(_hoy))
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () {
                        Navigator.pop(hoja);
                        _intentar(() => _prendasRepo.registrarUso(plan.prendaIds.where(porId.containsKey)),
                            '¡Listo! Sumamos un uso a cada prenda.');
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Lo usé'),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(hoja);
                      _intentar(() => _planRepo.quitar(plan.fecha), 'Plan quitado.');
                    },
                    child: const Text('Quitar'),
                  ),
                ]),
                const Divider(height: 28),
              ],
              Text(plan == null ? 'Elige un conjunto para este día' : 'Cambiar por otro conjunto',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              if (outfits.isEmpty)
                Text('Aún no tienes conjuntos guardados. Créalos en la pestaña Crear.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              for (final o in outfits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: MiniaturaPrenda(prenda: porId[o.prendaIds.firstOrNull], tamano: 44),
                  title: Text(o.nombre),
                  subtitle: Text('${o.prendaIds.length} prendas'),
                  trailing: o.favorito ? Icon(Icons.favorite, color: AppTheme.accent, size: 18) : null,
                  onTap: () {
                    Navigator.pop(hoja);
                    _planear(o, dia);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conjuntos(List<Outfit> outfits, Map<String, Prenda> porId) {
    if (outfits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text('Aún no tienes conjuntos guardados. Arma uno en la pestaña Crear.',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _TarjetaConjunto(
          outfit: outfits[i],
          porId: porId,
          onTap: () => _abrirConjunto(outfits[i], porId),
        ),
      ),
    );
  }

  Future<void> _abrirConjunto(Outfit o, Map<String, Prenda> porId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (hoja) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: StatefulBuilder(
            builder: (hoja, redibujar) => TarjetaOutfit(
              outfit: o,
              prendasPorId: porId,
              encabezado: IconButton(
                tooltip: o.favorito ? 'Quitar de favoritos' : 'Marcar como favorito',
                icon: Icon(o.favorito ? Icons.favorite : Icons.favorite_border, color: AppTheme.accent),
                onPressed: () {
                  redibujar(() => o = o.copyWith(favorito: !o.favorito));
                  _intentar(() => _outfitsRepo.marcarFavorito(o.id!, o.favorito),
                      o.favorito ? 'Agregado a favoritos.' : 'Quitado de favoritos.');
                },
              ),
              acciones: [
                Estrellas(
                  valor: o.calificacion,
                  alCambiar: (v) {
                    redibujar(() => o = o.copyWith(calificacion: v));
                    _outfitsRepo.calificar(o.id!, v).catchError((_) {});
                  },
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(hoja);
                    _intentar(() => _prendasRepo.registrarUso(o.prendaIds.where(porId.containsKey)),
                        '¡Listo! Sumamos un uso a cada prenda.');
                  },
                  child: const Text('Lo usé hoy'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(hoja);
                    final dia = await showDatePicker(
                      context: context,
                      initialDate: _hoy,
                      firstDate: _hoy,
                      lastDate: _hoy.add(const Duration(days: 365)),
                      helpText: 'Planear para el día',
                    );
                    if (dia != null) await _planear(o, dia);
                  },
                  child: const Text('Planear'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  onPressed: () {
                    Navigator.pop(hoja);
                    _intentar(() => _outfitsRepo.eliminar(o.id!), 'Conjunto eliminado.');
                  },
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca de un conjunto guardado con sus prendas en mosaico.
class _TarjetaConjunto extends StatelessWidget {
  const _TarjetaConjunto({required this.outfit, required this.porId, required this.onTap});

  final Outfit outfit;
  final Map<String, Prenda> porId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ids = outfit.prendaIds.take(4).toList();
    return Semantics(
      button: true,
      label: outfit.nombre,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 136,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 156,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.fondoPrenda,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Stack(
                  children: [
                    GridView.count(
                      crossAxisCount: ids.length == 1 ? 1 : 2,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: [for (final id in ids) FotoPrenda(prenda: porId[id], radio: 8, margen: 1)],
                    ),
                    if (outfit.favorito)
                      Align(alignment: Alignment.topRight, child: Icon(Icons.favorite, size: 18, color: AppTheme.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                outfit.nombre,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
