import 'package:material_ui/material_ui.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/theme/app_theme.dart';
import '../../collections/models/coleccion.dart';
import '../../wardrobe/models/prenda.dart';
import '../data/outfits_repositorio.dart';
import '../logic/generador_outfits.dart';
import '../models/outfit.dart';
import 'tarjeta_outfit.dart';

/// Generador de outfits (RF-03): elige ocasión y clima y recibe combinaciones
/// de tu armario. "Otras opciones" pide alternativas sin repetir y
/// "Ideas con IA" usa Gemini. Si llega una [coleccion], solo usa sus prendas (RF-05).
class GeneradorOutfitsVista extends StatefulWidget {
  const GeneradorOutfitsVista({
    super.key,
    required this.prendas,
    required this.repositorio,
    this.coleccion,
    this.alElegir,
  });

  final List<Prenda> prendas;
  final OutfitsRepositorio repositorio;
  final Coleccion? coleccion;

  /// Si llega, cada resultado muestra "Usar este" en vez de "Guardar" (pantalla Crear).
  final ValueChanged<Outfit>? alElegir;

  @override
  State<GeneradorOutfitsVista> createState() => _GeneradorOutfitsVistaState();
}

class _GeneradorOutfitsVistaState extends State<GeneradorOutfitsVista> {
  static const _generador = GeneradorOutfits();

  String _ocasion = 'casual';
  String _clima = 'cualquiera';
  List<Outfit> _resultados = [];
  final _mostrados = <String>{};
  final _guardados = <String>{};
  bool _generado = false;
  bool _pidiendoIA = false;

  List<Prenda> get _disponibles {
    final c = widget.coleccion;
    if (c == null) return widget.prendas;
    final ids = c.prendaIds.toSet();
    return widget.prendas.where((p) => ids.contains(p.id)).toList();
  }

  Map<String, Prenda> get _porId => {for (final p in widget.prendas) p.id!: p};

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _generar({bool alternativas = false}) {
    if (!alternativas) _mostrados.clear();
    final nuevos = _generador.generar(
      prendas: _disponibles,
      ocasion: _ocasion,
      clima: _clima,
      cantidad: 3,
      excluir: _mostrados,
    );
    setState(() {
      _generado = true;
      _resultados = nuevos;
      _mostrados.addAll(nuevos.map((o) => o.clave));
    });
    if (alternativas && nuevos.isEmpty) _avisar('Ya viste todas las combinaciones posibles con estas prendas.');
  }

  Future<void> _pedirIA() async {
    setState(() => _pidiendoIA = true);
    try {
      final excluir = _mostrados.map((k) => k.split('|')).toList();
      final nuevos = await widget.repositorio.generarConIA(
        ocasion: _ocasion,
        clima: _clima,
        excluir: excluir,
        prendas: _disponibles,
      );
      if (!mounted) return;
      setState(() {
        _generado = true;
        _resultados = nuevos;
        _mostrados.addAll(nuevos.map((o) => o.clave));
      });
      if (nuevos.isEmpty) _avisar('La IA no encontró combinaciones nuevas con tus prendas.');
    } on ErrorIA catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con la IA. Revisa tu conexión.');
    }
    if (mounted) setState(() => _pidiendoIA = false);
  }

  Future<void> _guardar(Outfit o) async {
    try {
      await widget.repositorio.guardar(o);
      if (!mounted) return;
      setState(() => _guardados.add(o.clave));
      _avisar('Outfit guardado.');
    } catch (_) {
      if (mounted) _avisar('No se pudo guardar el outfit.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = _disponibles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (widget.coleccion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Solo con las ${disponibles.length} prendas de "${widget.coleccion!.nombre}".',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        const Text('¿Para qué ocasión?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in OpcionesOutfit.ocasiones)
              ChoiceChip(
                label: Text(OpcionesOutfit.etiquetaOcasion(o)),
                selected: _ocasion == o,
                onSelected: (_) => setState(() => _ocasion = o),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('¿Qué clima hace?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in OpcionesOutfit.climas)
              ChoiceChip(
                label: Text(OpcionesOutfit.etiquetaClima(c)),
                selected: _clima == c,
                onSelected: (_) => setState(() => _clima = c),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (disponibles.length < 2)
          Text(
            'Necesitas al menos 2 prendas (por ejemplo, una superior y una inferior) para armar outfits.',
            style: TextStyle(color: AppTheme.textSecondary),
          )
        else ...[
          FilledButton.icon(
            onPressed: _pidiendoIA ? null : _generar,
            icon: const Icon(Icons.style),
            label: const Text('Generar outfits'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (!_generado || _pidiendoIA) ? null : () => _generar(alternativas: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Otras opciones'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pidiendoIA ? null : _pedirIA,
                  icon: _pidiendoIA
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Ideas con IA'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (_generado && _resultados.isEmpty)
          Text(
            'No encontramos combinaciones completas para esta ocasión y clima. '
            'Prueba otra ocasión o agrega más prendas (superior, inferior y calzado).',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        for (final o in _resultados)
          TarjetaOutfit(
            outfit: o,
            prendasPorId: _porId,
            acciones: [
              if (widget.alElegir != null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => widget.alElegir!(o),
                  icon: const Icon(Icons.check),
                  label: const Text('Usar este'),
                )
              else
              _guardados.contains(o.clave)
                  ? const TextButton(onPressed: null, child: Text('Guardado'))
                  : TextButton.icon(
                      onPressed: () => _guardar(o),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Guardar'),
                    ),
            ],
          ),
      ],
    );
  }
}
