import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/boton_degradado.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../planner/data/planificador_repositorio.dart';
import '../../planner/models/plan_dia.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../../wardrobe/screens/camara_screen.dart';
import '../data/outfits_repositorio.dart';
import '../models/outfit.dart';
import '../widgets/generador_outfits_vista.dart';

/// Pestaña Crear (RF-03, diseño de referencia): a la izquierda "Tus prendas",
/// a la derecha el lienzo del outfit, y abajo guardar, favoritos y calendario.
/// "Sugerir" arma el outfit automáticamente (generador local o con IA).
class CrearOutfitScreen extends StatefulWidget {
  const CrearOutfitScreen({
    super.key,
    this.prendasRepositorio,
    this.outfitsRepositorio,
    this.planificadorRepositorio,
  });

  final PrendasRepositorio? prendasRepositorio;
  final OutfitsRepositorio? outfitsRepositorio;
  final PlanificadorRepositorio? planificadorRepositorio;

  @override
  State<CrearOutfitScreen> createState() => _CrearOutfitScreenState();
}

class _CrearOutfitScreenState extends State<CrearOutfitScreen> {
  late final _prendasRepo = widget.prendasRepositorio ?? PrendasRepositorio();
  late final _outfitsRepo = widget.outfitsRepositorio ?? OutfitsRepositorio();
  late final _planRepo = widget.planificadorRepositorio ?? PlanificadorRepositorio();
  late final Stream<List<Prenda>> _prendas = _prendasRepo.observar();

  /// Prendas elegidas, en el orden en que se tocaron.
  final List<String> _elegidas = [];

  /// Si el outfit vino de una sugerencia, se guarda con su nombre y explicación.
  Outfit? _sugerido;
  bool _guardando = false;

  static const _ordenTipos = ['abrigo', 'superior', 'enterizo', 'inferior', 'calzado', 'accesorio'];

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _alternar(String id) => setState(() {
        _sugerido = null;
        _elegidas.contains(id) ? _elegidas.remove(id) : _elegidas.add(id);
      });

  Future<void> _sugerir(List<Prenda> prendas) async {
    final elegido = await showModalBottomSheet<Outfit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: GeneradorOutfitsVista(
          prendas: prendas,
          repositorio: _outfitsRepo,
          alElegir: (o) => Navigator.pop(context, o),
        ),
      ),
    );
    if (elegido == null) return;
    setState(() {
      _elegidas
        ..clear()
        ..addAll(elegido.prendaIds);
      _sugerido = elegido;
    });
  }

  Future<String?> _pedirNombre() {
    final controlador = TextEditingController(text: _sugerido?.nombre ?? 'Mi outfit');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del outfit'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej. Casual viernes'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, controlador.text), child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _guardar({bool favorito = false, bool planear = false}) async {
    if (_elegidas.length < 2) {
      _avisar('Elige al menos 2 prendas para armar el outfit.');
      return;
    }
    DateTime? dia;
    if (planear) {
      final hoy = DateTime.now();
      dia = await showDatePicker(
        context: context,
        initialDate: hoy,
        firstDate: DateTime(hoy.year, hoy.month, hoy.day),
        lastDate: hoy.add(const Duration(days: 365)),
        helpText: '¿Qué día te lo pondrás?',
      );
      if (dia == null || !mounted) return;
    }
    final nombre = (await _pedirNombre())?.trim();
    if (nombre == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      final guardado = await _outfitsRepo.guardar(Outfit(
        nombre: nombre.isEmpty ? 'Mi outfit' : nombre,
        prendaIds: List.of(_elegidas),
        ocasion: _sugerido?.ocasion ?? 'casual',
        clima: _sugerido?.clima ?? 'cualquiera',
        explicacion: _sugerido?.explicacion ?? '',
        origen: _sugerido?.origen ?? 'manual',
        favorito: favorito,
      ));
      if (dia != null) {
        await _planRepo.asignar(PlanDia(
          fecha: PlanDia.claveDe(dia),
          outfitId: guardado.id,
          outfitNombre: guardado.nombre,
          prendaIds: guardado.prendaIds,
        ));
      }
      if (!mounted) return;
      _avisar(dia != null
          ? 'Outfit guardado y programado para el ${dia.day}/${dia.month}.'
          : favorito
              ? 'Outfit guardado en favoritos.'
              : 'Outfit guardado.');
      setState(() {
        _elegidas.clear();
        _sugerido = null;
      });
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el outfit. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prenda>>(
      stream: _prendas,
      builder: (context, snap) {
        final prendas = [...?snap.data]
          ..sort((a, b) => _ordenTipos.indexOf(a.tipo).compareTo(_ordenTipos.indexOf(b.tipo)));
        final porId = {for (final p in prendas) p.id!: p};
        // Si se borró una prenda elegida, se quita del lienzo.
        _elegidas.removeWhere((id) => snap.hasData && !porId.containsKey(id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Crear Outfit'),
            actions: [
              if (_elegidas.isNotEmpty)
                IconButton(
                  tooltip: 'Vaciar',
                  icon: const Icon(Icons.layers_clear_outlined),
                  onPressed: () => setState(() {
                    _elegidas.clear();
                    _sugerido = null;
                  }),
                ),
              IconButton(
                tooltip: 'Sugerir outfit',
                icon: const Icon(Icons.auto_awesome),
                onPressed: prendas.length < 2 ? null : () => _sugerir(prendas),
              ),
            ],
          ),
          body: snap.hasError
              ? const Center(child: Text('No se pudo cargar tu armario.'))
              : !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : prendas.isEmpty
                      ? _sinPrendas()
                      : _contenido(prendas, porId),
        );
      },
    );
  }

  Widget _sinPrendas() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined, size: 56, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              'Para crear outfits primero agrega prendas a tu armario.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            BotonDegradado(
              texto: 'Añadir Prenda',
              icono: Icons.photo_camera_outlined,
              onPressed: () => agregarPrenda(context, repositorio: _prendasRepo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido(List<Prenda> prendas, Map<String, Prenda> porId) {
    final elegidas = [for (final id in _elegidas) ?porId[id]];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tus prendas', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: prendas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = prendas[i];
                      final elegida = _elegidas.contains(p.id);
                      return Semantics(
                        button: true,
                        selected: elegida,
                        label: p.nombre,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => _alternar(p.id!),
                          child: Container(
                            height: 76,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: elegida ? AppTheme.degradado : null,
                              color: elegida ? null : AppTheme.border,
                            ),
                            child: FotoPrenda(prenda: p, radio: 11, margen: 4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Lienzo(prendas: elegidas, alQuitar: (p) => _alternar(p.id!))),
                if (_sugerido != null && _sugerido!.explicacion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_sugerido!.explicacion,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                const SizedBox(height: 12),
                BotonDegradado(texto: 'Guardar Outfit', alto: 46, tamanoTexto: 16, cargando: _guardando,
                    onPressed: () => _guardar()),
                const SizedBox(height: 8),
                BotonContorno(
                  texto: 'Añadir a favoritos',
                  icono: Icons.favorite_border,
                  alto: 44,
                  onPressed: _guardando ? null : () => _guardar(favorito: true),
                ),
                const SizedBox(height: 8),
                BotonDegradado(
                  texto: 'Calendario',
                  icono: Icons.calendar_month_outlined,
                  alto: 46,
                  tamanoTexto: 16,
                  onPressed: _guardando ? null : () => _guardar(planear: true),
                ),
                const SizedBox(height: 4),
                Text('Programar qué ponerse',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lienzo blanco donde se ve el outfit armado.
class _Lienzo extends StatelessWidget {
  const _Lienzo({required this.prendas, required this.alQuitar});

  final List<Prenda> prendas;
  final ValueChanged<Prenda> alQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fondoPrenda,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(10),
      child: prendas.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Toca tus prendas de la izquierda para armar el outfit, o usa ✨ para que te sugiera uno.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6F6A85)),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final columnas = prendas.length <= 2 ? 1 : 2;
                final filas = (prendas.length / columnas).ceil();
                final lado = [
                  (c.maxWidth - (columnas - 1) * 8) / columnas,
                  (c.maxHeight - (filas - 1) * 8) / filas,
                ].reduce((a, b) => a < b ? a : b);
                return Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in prendas)
                        Tooltip(
                          message: 'Quitar ${p.nombre}',
                          child: GestureDetector(
                            onTap: () => alQuitar(p),
                            child: SizedBox.square(dimension: lado, child: FotoPrenda(prenda: p, radio: 10, margen: 2)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
