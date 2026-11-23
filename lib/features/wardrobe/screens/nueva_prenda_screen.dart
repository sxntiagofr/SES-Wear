import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/theme/app_theme.dart';
import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';
import '../widgets/campos_prenda.dart';

/// Pantalla "Nueva prenda": muestra la foto, la IA llena el formulario
/// (tipo, categoría, colores, tela, formalidad, estación) y el usuario
/// puede corregir antes de guardar.
class NuevaPrendaScreen extends StatefulWidget {
  const NuevaPrendaScreen({
    super.key,
    required this.foto,
    this.tipoImagen = 'image/jpeg',
    this.repositorio,
    this.quitarFondoAlAbrir = true,
  });

  final Uint8List foto;
  final String tipoImagen;
  final PrendasRepositorio? repositorio;

  /// Quita el fondo apenas se abre la pantalla (remove.bg).
  final bool quitarFondoAlAbrir;

  @override
  State<NuevaPrendaScreen> createState() => _NuevaPrendaScreenState();
}

class _NuevaPrendaScreenState extends State<NuevaPrendaScreen> {
  late final PrendasRepositorio _repo;
  final _form = GlobalKey<FormState>();

  final _formulario = FormularioPrenda();

  bool _analizando = true;
  bool _guardando = false;
  bool _identificadaPorIA = false;
  String? _aviso;

  // Foto que se va a guardar: la original o la versión sin fondo (PNG).
  late Uint8List _foto = widget.foto;
  late String _tipoFoto = widget.tipoImagen;
  bool _sinFondo = false;
  bool _quitandoFondo = false;
  String? _avisoFondo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repositorio ?? PrendasRepositorio();
    _analizar();
    if (widget.quitarFondoAlAbrir) _quitarFondo();
  }

  @override
  void dispose() {
    _formulario.dispose();
    super.dispose();
  }

  Future<void> _analizar() async {
    setState(() {
      _analizando = true;
      _aviso = null;
    });
    try {
      final resultado = await _repo.identificar(widget.foto, tipo: widget.tipoImagen);
      if (!mounted) return;
      if (!resultado.esPrenda) {
        setState(() => _aviso =
            'No reconocí ninguna prenda en la foto. Toma otra con buena luz y la prenda completa, o llena los datos a mano.');
        return;
      }
      _llenar(resultado.prenda);
    } on ErrorIA catch (e) {
      if (mounted) setState(() => _aviso = '${e.mensaje} Puedes llenar los datos a mano.');
    } catch (_) {
      if (mounted) {
        setState(() => _aviso = 'No se pudo conectar con la IA. Puedes llenar los datos a mano.');
      }
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  void _llenar(Prenda p) {
    setState(() {
      _identificadaPorIA = true;
      _formulario.llenar(p);
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final prenda = _formulario.aPrenda(identificadaPorIA: _identificadaPorIA);
    try {
      await _repo.guardar(prenda, _foto, tipo: _tipoFoto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Guardado exitoso! "${prenda.nombre}" ya está en tu armario.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la prenda. Inténtalo de nuevo.')),
      );
    }
  }

  /// remove.bg acepta JPG, PNG y WEBP.
  bool get _fondoSoportado => const ['image/jpeg', 'image/png', 'image/webp'].contains(widget.tipoImagen);

  /// Mensaje claro para cada error de la Cloud Function `quitarFondo`.
  static String mensajeFondo(Object error) {
    if (error is ErrorFondo) return error.mensaje;
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'not-found' || 'internal' when (error.message ?? '').toLowerCase() == error.code =>
          'El servicio para quitar el fondo aún no está publicado en el servidor.',
        'not-found' => 'El servicio para quitar el fondo aún no está publicado en el servidor.',
        'unauthenticated' => 'Vuelve a iniciar sesión para quitar el fondo.',
        _ => error.message ?? 'No se pudo quitar el fondo.',
      };
    }
    return 'No se pudo quitar el fondo. Revisa tu conexión.';
  }

  /// Quita el fondo con remove.bg (Cloud Function). Se hace automáticamente al
  /// abrir la pantalla; si falla, la prenda se puede guardar con la foto original.
  Future<void> _quitarFondo() async {
    if (!_fondoSoportado) {
      setState(() => _avisoFondo = 'Para quitar el fondo la foto debe ser JPG, PNG o WEBP.');
      return;
    }
    setState(() {
      _quitandoFondo = true;
      _avisoFondo = null;
    });
    try {
      final resultado = await _repo.quitarFondo(widget.foto, tipo: widget.tipoImagen);
      if (!mounted) return;
      setState(() {
        _foto = resultado.foto;
        _tipoFoto = resultado.tipo;
        _sinFondo = true;
      });
    } catch (e) {
      if (mounted) setState(() => _avisoFondo = mensajeFondo(e));
    } finally {
      if (mounted) setState(() => _quitandoFondo = false);
    }
  }

  void _restaurarFoto() {
    setState(() {
      _foto = widget.foto;
      _tipoFoto = widget.tipoImagen;
      _sinFondo = false;
    });
  }

  Widget _botonFondo() {
    final ocupado = _quitandoFondo || _guardando;
    if (_quitandoFondo) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Quitando el fondo…'),
        ],
      );
    }
    if (_sinFondo) {
      return TextButton.icon(
        onPressed: ocupado ? null : _restaurarFoto,
        icon: const Icon(Icons.undo),
        label: const Text('Usar foto original'),
      );
    }
    return Column(
      children: [
        if (_avisoFondo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_avisoFondo!, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          ),
        OutlinedButton.icon(
          onPressed: ocupado ? null : _quitarFondo,
          icon: const Icon(Icons.auto_fix_high),
          label: Text(_avisoFondo == null ? 'Quitar fondo' : 'Reintentar quitar fondo'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva prenda')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: _sinFondo ? Colors.white : Colors.transparent,
                    child: Image.memory(_foto, fit: _sinFondo ? BoxFit.contain : BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: _botonFondo()),
              const SizedBox(height: 8),
              _estadoIA(),
              const SizedBox(height: 12),
              CamposPrenda(
                formulario: _formulario,
                habilitado: !_analizando && !_guardando,
                alCambiar: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (_analizando || _guardando || _quitandoFondo) ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_guardando ? 'Guardando…' : 'Guardar en mi armario'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoIA() {
    if (_analizando) {
      return const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Expanded(child: Text('Analizando la prenda con IA…')),
        ],
      );
    }
    if (_aviso != null) {
      return Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_aviso!)),
          TextButton(onPressed: _analizar, child: const Text('Reintentar')),
        ],
      );
    }
    return const Row(
      children: [
        Icon(Icons.auto_awesome, color: AppTheme.primary),
        SizedBox(width: 8),
        Expanded(child: Text('La IA llenó los datos. Revísalos y corrige lo que haga falta.')),
      ],
    );
  }

}
