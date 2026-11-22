import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/colores.dart';
import '../../collections/screens/colecciones_screen.dart';
import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';
import '../widgets/campos_prenda.dart';
import '../widgets/tarjeta_prenda.dart';
import 'detalle_prenda_screen.dart';
import 'camara_screen.dart';

/// Armario virtual (RF-02): prendas guardadas en Firestore, búsqueda y filtros
/// por tipo, color, estación y formalidad, y botón para agregar una prenda
/// tomando una foto (la IA identifica la prenda, RF-01).
class ArmarioScreen extends StatefulWidget {
  const ArmarioScreen({super.key, this.repositorio, this.tipoInicial});

  final PrendasRepositorio? repositorio;

  /// Abre el armario filtrado por un tipo (categorías de Inicio).
  final String? tipoInicial;

  @override
  State<ArmarioScreen> createState() => _ArmarioScreenState();
}

class _ArmarioScreenState extends State<ArmarioScreen> {
  late final PrendasRepositorio _repo;
  late final Stream<List<Prenda>> _prendas;
  final _busqueda = TextEditingController();
  late FiltroPrendas _filtro = FiltroPrendas(tipo: widget.tipoInicial);

  @override
  void initState() {
    super.initState();
    _repo = widget.repositorio ?? PrendasRepositorio();
    _prendas = _repo.observar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _elegirOrigen() => agregarPrenda(context, repositorio: _repo);

  Future<void> _confirmarEliminar(Prenda prenda) async {
    final eliminar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar prenda'),
        content: Text('¿Eliminar "${prenda.nombre}" de tu armario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (eliminar != true) return;
    try {
      await _repo.eliminar(prenda);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la prenda. Revisa tu conexión e inténtalo de nuevo.')),
      );
    }
  }

  void _abrirDetalle(Prenda prenda) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetallePrendaScreen(prenda: prenda, repositorio: _repo),
    ));
  }

  Future<void> _abrirFiltros(List<Prenda> prendas) async {
    final colores = FiltroPrendas.coloresDe(prendas);
    final nuevo = await showModalBottomSheet<FiltroPrendas>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaFiltros(filtro: _filtro, colores: colores),
    );
    if (nuevo != null) setState(() => _filtro = nuevo);
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    setState(() => _filtro = const FiltroPrendas());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prenda>>(
      stream: _prendas,
      builder: (context, snapshot) {
        final prendas = snapshot.data ?? const <Prenda>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi armario'),
            actions: [
              IconButton(
                tooltip: 'Colecciones',
                icon: const Icon(Icons.collections_bookmark_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ColeccionesScreen(prendasRepositorio: _repo)),
                ),
              ),
              IconButton(
                tooltip: 'Filtros',
                onPressed: prendas.isEmpty ? null : () => _abrirFiltros(prendas),
                icon: Badge(
                  isLabelVisible: _filtro.cantidad > 0,
                  label: Text('${_filtro.cantidad}'),
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _elegirOrigen,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Agregar prenda'),
          ),
          body: _cuerpo(snapshot, prendas),
        );
      },
    );
  }

  Widget _cuerpo(AsyncSnapshot<List<Prenda>> snapshot, List<Prenda> prendas) {
    if (snapshot.hasError) {
      return const Center(child: Text('No se pudo cargar tu armario.'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prendas.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checkroom_outlined, size: 56, color: AppTheme.primary),
              SizedBox(height: 12),
              Text(
                'Tu armario está vacío.\nToma una foto de una prenda y la IA la registra por ti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final visibles = _filtro.aplicar(prendas);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _busqueda,
            onChanged: (v) => setState(() => _filtro = _filtro.conTexto(v)),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, color, tela…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _busqueda.clear();
                        setState(() => _filtro = _filtro.conTexto(''));
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final tipo in [null, ...OpcionesPrenda.tipos])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tipo == null ? 'Todas' : CamposPrenda.capitalizar(tipo)),
                    selected: _filtro.tipo == tipo,
                    onSelected: (_) => setState(() => _filtro = _filtro.conTipo(tipo)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ninguna prenda coincide con la búsqueda.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      TextButton(onPressed: _limpiarFiltros, child: const Text('Quitar filtros')),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (context, i) => TarjetaPrenda(
                    prenda: visibles[i],
                    onTap: () => _abrirDetalle(visibles[i]),
                    onLongPress: () => _confirmarEliminar(visibles[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Hoja inferior con los filtros de color, estación y formalidad.
class _HojaFiltros extends StatefulWidget {
  const _HojaFiltros({required this.filtro, required this.colores});

  final FiltroPrendas filtro;
  final List<String> colores;

  @override
  State<_HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<_HojaFiltros> {
  late FiltroPrendas _f = widget.filtro;

  Widget _grupo(String titulo, List<String> opciones, String? actual, FiltroPrendas Function(String?) cambiar,
      {bool conColor = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in opciones)
              FilterChip(
                avatar: conColor ? CircleAvatar(backgroundColor: colorDeNombre(o)) : null,
                label: Text(CamposPrenda.capitalizar(o)),
                selected: actual == o,
                onSelected: (sel) => setState(() => _f = cambiar(sel ? o : null)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Filtros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (widget.colores.isNotEmpty) _grupo('Color', widget.colores, _f.color, _f.conColor, conColor: true),
            _grupo('Estación', OpcionesPrenda.estaciones, _f.estacion, _f.conEstacion),
            _grupo('Formalidad', OpcionesPrenda.formalidades, _f.formalidad, _f.conFormalidad),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                        context, FiltroPrendas(texto: _f.texto, tipo: _f.tipo)),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context, _f), child: const Text('Aplicar')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
