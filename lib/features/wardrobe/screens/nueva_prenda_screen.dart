import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';

/// Abre la cámara (o la galería) y, si el usuario toma una foto, abre la
/// pantalla "Nueva prenda". Devuelve `true` si la prenda se guardó.
Future<bool> agregarPrendaConFoto(
  BuildContext context, {
  ImageSource origen = ImageSource.camera,
  PrendasRepositorio? repositorio,
}) async {
  final XFile? foto;
  try {
    // Se reduce a ~1024 px: suficiente para la IA y más rápido de subir (RNF-01).
    foto = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la cámara. Revisa los permisos de la app.')),
      );
    }
    return false;
  }
  if (foto == null || !context.mounted) return false;

  final bytes = await foto.readAsBytes();
  final tipoImagen = _tipoDeImagen(foto);
  if (!context.mounted) return false;
  final guardada = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => NuevaPrendaScreen(
        foto: bytes,
        tipoImagen: tipoImagen,
        repositorio: repositorio,
      ),
    ),
  );
  return guardada == true;
}

String _tipoDeImagen(XFile foto) {
  final tipo = foto.mimeType;
  if (tipo != null && tipo.startsWith('image/')) return tipo;
  final nombre = foto.name.toLowerCase();
  if (nombre.endsWith('.png')) return 'image/png';
  if (nombre.endsWith('.webp')) return 'image/webp';
  if (nombre.endsWith('.heic') || nombre.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Pantalla "Nueva prenda": muestra la foto, la IA llena el formulario
/// (tipo, categoría, colores, tela, estilo, formalidad, estación) y el usuario
/// puede corregir antes de guardar.
class NuevaPrendaScreen extends StatefulWidget {
  const NuevaPrendaScreen({
    super.key,
    required this.foto,
    this.tipoImagen = 'image/jpeg',
    this.repositorio,
  });

  final Uint8List foto;
  final String tipoImagen;
  final PrendasRepositorio? repositorio;

  @override
  State<NuevaPrendaScreen> createState() => _NuevaPrendaScreenState();
}

class _NuevaPrendaScreenState extends State<NuevaPrendaScreen> {
  late final PrendasRepositorio _repo;
  final _form = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _categoria = TextEditingController();
  final _colorPrimario = TextEditingController();
  final _colorSecundario = TextEditingController();
  final _tela = TextEditingController();
  final _estilo = TextEditingController();
  final _etiquetas = TextEditingController();
  String _tipo = 'superior';
  String _formalidad = 'casual';
  String _estacion = 'todo el año';

  bool _analizando = true;
  bool _guardando = false;
  bool _identificadaPorIA = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _repo = widget.repositorio ?? PrendasRepositorio();
    _analizar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _categoria, _colorPrimario, _colorSecundario, _tela, _estilo, _etiquetas]) {
      c.dispose();
    }
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
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _aviso = '${e.message ?? 'La IA no está disponible.'} Puedes llenar los datos a mano.');
      }
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
      _nombre.text = p.nombre;
      _categoria.text = p.categoria;
      _colorPrimario.text = p.colorPrimario;
      _colorSecundario.text = p.colorSecundario;
      _tela.text = p.tela;
      _estilo.text = p.estilo;
      _etiquetas.text = p.etiquetas.join(', ');
      _tipo = p.tipo;
      _formalidad = p.formalidad;
      _estacion = p.estacion;
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final prenda = Prenda(
      nombre: _nombre.text.trim(),
      tipo: _tipo,
      categoria: _categoria.text.trim().toLowerCase(),
      colorPrimario: _colorPrimario.text.trim().toLowerCase(),
      colorSecundario: _colorSecundario.text.trim().toLowerCase(),
      tela: _tela.text.trim().toLowerCase(),
      estilo: _estilo.text.trim().toLowerCase(),
      formalidad: _formalidad,
      estacion: _estacion,
      etiquetas: _etiquetas.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      identificadaPorIA: _identificadaPorIA,
    );
    try {
      await _repo.guardar(prenda, widget.foto, tipo: widget.tipoImagen);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${prenda.nombre}" se guardó en tu armario.')),
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
                  child: Image.memory(widget.foto, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              _estadoIA(),
              const SizedBox(height: 12),
              ..._campos(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (_analizando || _guardando) ? null : _guardar,
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
          const Icon(Icons.info_outline, color: AppTheme.error),
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

  List<Widget> _campos() {
    final habilitado = !_analizando && !_guardando;
    Widget texto(TextEditingController c, String etiqueta, {bool requerido = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: habilitado,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
          validator: requerido
              ? (v) => (v == null || v.trim().isEmpty) ? 'Escribe $etiqueta'.toLowerCase() : null
              : null,
        ),
      );
    }

    Widget opciones(String etiqueta, String valor, List<String> lista, ValueChanged<String> alCambiar) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$etiqueta-$valor'),
          initialValue: valor,
          decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
          items: [for (final o in lista) DropdownMenuItem(value: o, child: Text(_capitalizar(o)))],
          onChanged: habilitado ? (v) => alCambiar(v!) : null,
        ),
      );
    }

    return [
      texto(_nombre, 'Nombre', requerido: true),
      opciones('Tipo', _tipo, OpcionesPrenda.tipos, (v) => setState(() => _tipo = v)),
      texto(_categoria, 'Categoría (jean, buso, tenis…)'),
      Row(
        children: [
          Expanded(child: texto(_colorPrimario, 'Color principal')),
          const SizedBox(width: 12),
          Expanded(child: texto(_colorSecundario, 'Color secundario')),
        ],
      ),
      texto(_tela, 'Tela'),
      texto(_estilo, 'Estilo'),
      opciones('Formalidad', _formalidad, OpcionesPrenda.formalidades,
          (v) => setState(() => _formalidad = v)),
      opciones('Estación', _estacion, OpcionesPrenda.estaciones, (v) => setState(() => _estacion = v)),
      texto(_etiquetas, 'Etiquetas (separadas por coma)'),
    ];
  }

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
