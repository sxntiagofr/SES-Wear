import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/colores.dart';
import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';
import '../widgets/campos_prenda.dart';
import 'editar_prenda_screen.dart';

/// Detalle de una prenda: datos, uso, y acciones (usar hoy, editar, eliminar).
class DetallePrendaScreen extends StatefulWidget {
  const DetallePrendaScreen({super.key, required this.prenda, required this.repositorio});

  final Prenda prenda;
  final PrendasRepositorio repositorio;

  @override
  State<DetallePrendaScreen> createState() => _DetallePrendaScreenState();
}

class _DetallePrendaScreenState extends State<DetallePrendaScreen> {
  late final Stream<List<Prenda>> _prendas = widget.repositorio.observar();
  bool _ocupado = false;

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _usarHoy(Prenda p) async {
    setState(() => _ocupado = true);
    try {
      await widget.repositorio.registrarUso([p.id!]);
      if (mounted) _avisar('¡Listo! Sumamos un uso a "${p.nombre}".');
    } catch (_) {
      if (mounted) _avisar('No se pudo registrar el uso. Revisa tu conexión.');
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _eliminar(Prenda p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: Text('¿Eliminar "${p.nombre}" de tu armario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await widget.repositorio.eliminar(p);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _avisar('No se pudo eliminar la prenda. Revisa tu conexión e inténtalo de nuevo.');
    }
  }

  static String _fecha(DateTime f) => '${f.day}/${f.month}/${f.year}';

  static String _pesos(double v) {
    final entero = v.round().toString();
    final conPuntos = entero.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '\$$conPuntos';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prenda>>(
      stream: _prendas,
      builder: (context, snap) {
        final lista = snap.data;
        final p = lista == null
            ? widget.prenda
            : lista.firstWhere((x) => x.id == widget.prenda.id, orElse: () => widget.prenda);
        return Scaffold(
          appBar: AppBar(
            title: Text(p.nombre, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _ocupado
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EditarPrendaScreen(prenda: p, repositorio: widget.repositorio),
                        )),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _ocupado ? null : () => _eliminar(p),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: AppTheme.primaryLight,
                    child: p.fotoUrl == null
                        ? const Icon(Icons.checkroom, size: 72, color: AppTheme.primary)
                        : Image.network(
                            p.fotoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined, size: 56, color: AppTheme.primary),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in [p.tipo, p.categoria, p.formalidad, p.estacion, p.tela, p.estilo])
                    if (t.isNotEmpty) Chip(label: Text(CamposPrenda.capitalizar(t))),
                  for (final c in [p.colorPrimario, p.colorSecundario])
                    if (c.isNotEmpty)
                      Chip(
                        avatar: CircleAvatar(backgroundColor: colorDeNombre(c)),
                        label: Text(CamposPrenda.capitalizar(c)),
                      ),
                ],
              ),
              if (p.etiquetas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.etiquetas.map((e) => '#$e').join('  '),
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usada ${p.vecesUsada} ${p.vecesUsada == 1 ? 'vez' : 'veces'}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        p.ultimoUso == null ? 'Aún no la has marcado como usada.' : 'Última vez: ${_fecha(p.ultimoUso!)}',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      if (p.precio != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.costoPorUso == null
                              ? 'Precio: ${_pesos(p.precio!)}'
                              : 'Costo por uso: ${_pesos(p.costoPorUso!)} (precio ${_pesos(p.precio!)})',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _ocupado ? null : () => _usarHoy(p),
                icon: const Icon(Icons.today),
                label: const Text('La usé hoy'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EditarPrendaScreen(prenda: p, repositorio: widget.repositorio),
                        )),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
