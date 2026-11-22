import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/miniatura_prenda.dart';
import '../../outfits/data/outfits_repositorio.dart';
import '../../outfits/widgets/generador_outfits_vista.dart';
import '../../wardrobe/data/prendas_repositorio.dart';
import '../../wardrobe/models/prenda.dart';
import '../data/colecciones_repositorio.dart';
import '../models/coleccion.dart';

/// Colecciones personalizadas (RF-05): p. ej. "Ropa de oficina" o "Viaje a la costa".
class ColeccionesScreen extends StatefulWidget {
  const ColeccionesScreen({
    super.key,
    required this.prendasRepositorio,
    this.coleccionesRepositorio,
    this.outfitsRepositorio,
  });

  final PrendasRepositorio prendasRepositorio;
  final ColeccionesRepositorio? coleccionesRepositorio;
  final OutfitsRepositorio? outfitsRepositorio;

  @override
  State<ColeccionesScreen> createState() => _ColeccionesScreenState();
}

class _ColeccionesScreenState extends State<ColeccionesScreen> {
  late final ColeccionesRepositorio _repo = widget.coleccionesRepositorio ?? ColeccionesRepositorio();
  late final Stream<List<Coleccion>> _colecciones = _repo.observar();
  late final Stream<List<Prenda>> _prendas = widget.prendasRepositorio.observar();

  Future<void> _crear() async {
    final datos = await pedirNombreColeccion(context);
    if (datos == null) return;
    try {
      await _repo.crear(datos.nombre, descripcion: datos.descripcion);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo crear la colección.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colecciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nueva colección'),
      ),
      body: StreamBuilder<List<Prenda>>(
        stream: _prendas,
        builder: (context, snapPrendas) {
          final porId = {for (final p in snapPrendas.data ?? const <Prenda>[]) p.id!: p};
          return StreamBuilder<List<Coleccion>>(
            stream: _colecciones,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('No se pudieron cargar tus colecciones.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final colecciones = snap.data!;
              if (colecciones.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Agrupa tus prendas en colecciones como "Ropa de oficina" o "Viaje a la costa" '
                      'y genera outfits solo con ellas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: colecciones.length,
                itemBuilder: (context, i) {
                  final c = colecciones[i];
                  final existentes = c.prendaIds.where(porId.containsKey).toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          '${existentes.length} ${existentes.length == 1 ? 'prenda' : 'prendas'}',
                          if (c.descripcion.isNotEmpty) c.descripcion,
                        ].join(' · '),
                      ),
                      trailing: existentes.isEmpty
                          ? const Icon(Icons.chevron_right)
                          : MiniaturaPrenda(prenda: porId[existentes.first], tamano: 44),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ColeccionDetalleScreen(
                          coleccionId: c.id!,
                          coleccionesRepositorio: _repo,
                          prendasRepositorio: widget.prendasRepositorio,
                          outfitsRepositorio: widget.outfitsRepositorio,
                        ),
                      )),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Pide nombre y descripción de una colección.
Future<({String nombre, String descripcion})?> pedirNombreColeccion(BuildContext context, {Coleccion? actual}) {
  final nombre = TextEditingController(text: actual?.nombre ?? '');
  final descripcion = TextEditingController(text: actual?.descripcion ?? '');
  final form = GlobalKey<FormState>();
  return showDialog<({String nombre, String descripcion})>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(actual == null ? 'Nueva colección' : 'Editar colección'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nombre,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre (p. ej. Ropa de oficina)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
            ),
            TextFormField(
              controller: descripcion,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, (nombre: nombre.text.trim(), descripcion: descripcion.text.trim()));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

/// Detalle de una colección: sus prendas, elegir prendas y generar outfits con ellas.
class ColeccionDetalleScreen extends StatefulWidget {
  const ColeccionDetalleScreen({
    super.key,
    required this.coleccionId,
    required this.coleccionesRepositorio,
    required this.prendasRepositorio,
    this.outfitsRepositorio,
  });

  final String coleccionId;
  final ColeccionesRepositorio coleccionesRepositorio;
  final PrendasRepositorio prendasRepositorio;
  final OutfitsRepositorio? outfitsRepositorio;

  @override
  State<ColeccionDetalleScreen> createState() => _ColeccionDetalleScreenState();
}

class _ColeccionDetalleScreenState extends State<ColeccionDetalleScreen> {
  late final Stream<List<Coleccion>> _colecciones = widget.coleccionesRepositorio.observar();
  late final Stream<List<Prenda>> _prendas = widget.prendasRepositorio.observar();

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _elegirPrendas(Coleccion c, List<Prenda> prendas) async {
    final seleccion = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectorPrendas(prendas: prendas, iniciales: c.prendaIds.toSet()),
    );
    if (seleccion == null) return;
    try {
      await widget.coleccionesRepositorio.actualizar(
        Coleccion(id: c.id, nombre: c.nombre, descripcion: c.descripcion, prendaIds: seleccion.toList()),
      );
    } catch (_) {
      if (mounted) _avisar('No se pudo actualizar la colección.');
    }
  }

  Future<void> _editar(Coleccion c) async {
    final datos = await pedirNombreColeccion(context, actual: c);
    if (datos == null) return;
    try {
      await widget.coleccionesRepositorio.actualizar(
        Coleccion(id: c.id, nombre: datos.nombre, descripcion: datos.descripcion, prendaIds: c.prendaIds),
      );
    } catch (_) {
      if (mounted) _avisar('No se pudo actualizar la colección.');
    }
  }

  Future<void> _eliminar(Coleccion c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar colección'),
        content: Text('¿Eliminar "${c.nombre}"? Las prendas siguen en tu armario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.coleccionesRepositorio.eliminar(c.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _avisar('No se pudo eliminar la colección.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prenda>>(
      stream: _prendas,
      builder: (context, snapPrendas) => StreamBuilder<List<Coleccion>>(
        stream: _colecciones,
        builder: (context, snap) {
          final prendas = snapPrendas.data ?? const <Prenda>[];
          final c = snap.data?.where((x) => x.id == widget.coleccionId).firstOrNull;
          if (c == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: snap.hasData ? const Text('Esta colección ya no existe.') : const CircularProgressIndicator(),
              ),
            );
          }
          final ids = c.prendaIds.toSet();
          final incluidas = prendas.where((p) => ids.contains(p.id)).toList();
          return Scaffold(
            appBar: AppBar(
              title: Text(c.nombre),
              actions: [
                IconButton(tooltip: 'Editar nombre', icon: const Icon(Icons.edit_outlined), onPressed: () => _editar(c)),
                IconButton(tooltip: 'Eliminar colección', icon: const Icon(Icons.delete_outline), onPressed: () => _eliminar(c)),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (c.descripcion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(c.descripcion, style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in incluidas) MiniaturaPrenda(prenda: p, tamano: 72)],
                ),
                if (incluidas.isEmpty)
                  Text('Esta colección aún no tiene prendas.', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: prendas.isEmpty ? null : () => _elegirPrendas(c, prendas),
                  icon: const Icon(Icons.checklist),
                  label: const Text('Elegir prendas'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: incluidas.length < 2
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text('Outfits: ${c.nombre}')),
                              body: GeneradorOutfitsVista(
                                prendas: prendas,
                                coleccion: c,
                                repositorio: widget.outfitsRepositorio ?? OutfitsRepositorio(),
                              ),
                            ),
                          )),
                  icon: const Icon(Icons.style),
                  label: const Text('Generar outfits con esta colección'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectorPrendas extends StatefulWidget {
  const _SelectorPrendas({required this.prendas, required this.iniciales});

  final List<Prenda> prendas;
  final Set<String> iniciales;

  @override
  State<_SelectorPrendas> createState() => _SelectorPrendasState();
}

class _SelectorPrendasState extends State<_SelectorPrendas> {
  late final Set<String> _seleccion = {...widget.iniciales};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${_seleccion.length} seleccionadas',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context, _seleccion), child: const Text('Listo')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in widget.prendas)
                    CheckboxListTile(
                      value: _seleccion.contains(p.id),
                      onChanged: (v) => setState(() => v == true ? _seleccion.add(p.id!) : _seleccion.remove(p.id)),
                      secondary: MiniaturaPrenda(prenda: p, tamano: 44),
                      title: Text(p.nombre),
                      subtitle: Text([p.tipo, p.colorPrimario].where((e) => e.isNotEmpty).join(' · ')),
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
