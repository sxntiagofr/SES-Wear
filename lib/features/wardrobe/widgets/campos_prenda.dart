import 'package:material_ui/material_ui.dart';

import '../models/prenda.dart';

/// Estado del formulario de una prenda (nueva o editada).
class FormularioPrenda {
  final nombre = TextEditingController();
  final categoria = TextEditingController();
  final colorPrimario = TextEditingController();
  final colorSecundario = TextEditingController();
  final tela = TextEditingController();
  final estilo = TextEditingController();
  final etiquetas = TextEditingController();
  final precio = TextEditingController();
  String tipo = 'superior';
  String formalidad = 'casual';
  String estacion = 'todo el año';

  void llenar(Prenda p) {
    nombre.text = p.nombre;
    categoria.text = p.categoria;
    colorPrimario.text = p.colorPrimario;
    colorSecundario.text = p.colorSecundario;
    tela.text = p.tela;
    estilo.text = p.estilo;
    etiquetas.text = p.etiquetas.join(', ');
    if (p.precio != null) precio.text = p.precio!.toStringAsFixed(0);
    tipo = p.tipo;
    formalidad = p.formalidad;
    estacion = p.estacion;
  }

  /// Precio escrito por el usuario: acepta "120.000", "120000" o "120 000".
  double? get precioNumero {
    final limpio = precio.text.replaceAll(RegExp(r'[^0-9]'), '');
    return limpio.isEmpty ? null : double.tryParse(limpio);
  }

  /// Prenda con los datos del formulario, normalizados.
  Prenda aPrenda({String? id, bool identificadaPorIA = false, Prenda? base}) {
    final datos = Prenda(
      id: id,
      nombre: nombre.text.trim(),
      tipo: tipo,
      categoria: categoria.text.trim().toLowerCase(),
      colorPrimario: colorPrimario.text.trim().toLowerCase(),
      colorSecundario: colorSecundario.text.trim().toLowerCase(),
      tela: tela.text.trim().toLowerCase(),
      estilo: estilo.text.trim().toLowerCase(),
      formalidad: formalidad,
      estacion: estacion,
      etiquetas: etiquetas.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      precio: precioNumero,
      identificadaPorIA: identificadaPorIA,
    );
    if (base == null) return datos;
    // Conserva lo que no se edita (foto, usos, fechas).
    return base.copyWith(
      nombre: datos.nombre,
      tipo: datos.tipo,
      categoria: datos.categoria,
      colorPrimario: datos.colorPrimario,
      colorSecundario: datos.colorSecundario,
      tela: datos.tela,
      estilo: datos.estilo,
      formalidad: datos.formalidad,
      estacion: datos.estacion,
      etiquetas: datos.etiquetas,
      precio: datos.precio,
      quitarPrecio: datos.precio == null,
    );
  }

  void dispose() {
    for (final c in [nombre, categoria, colorPrimario, colorSecundario, tela, estilo, etiquetas, precio]) {
      c.dispose();
    }
  }
}

/// Campos del formulario de prenda, compartidos por "Nueva prenda" y "Editar prenda".
class CamposPrenda extends StatelessWidget {
  const CamposPrenda({super.key, required this.formulario, required this.habilitado, required this.alCambiar});

  final FormularioPrenda formulario;
  final bool habilitado;

  /// Se llama al cambiar un menú desplegable, para redibujar la pantalla.
  final VoidCallback alCambiar;

  static String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final f = formulario;

    Widget texto(TextEditingController c, String etiqueta, {bool requerido = false, TextInputType? teclado}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: habilitado,
          keyboardType: teclado,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
          validator: requerido
              ? (v) => (v == null || v.trim().isEmpty) ? 'Escribe el ${etiqueta.toLowerCase()}' : null
              : null,
        ),
      );
    }

    Widget opciones(String etiqueta, String valor, List<String> lista, ValueChanged<String> cambiar) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$etiqueta-$valor'),
          initialValue: valor,
          decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
          items: [for (final o in lista) DropdownMenuItem(value: o, child: Text(capitalizar(o)))],
          onChanged: habilitado
              ? (v) {
                  cambiar(v!);
                  alCambiar();
                }
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        texto(f.nombre, 'Nombre', requerido: true),
        opciones('Tipo', f.tipo, OpcionesPrenda.tipos, (v) => f.tipo = v),
        texto(f.categoria, 'Categoría (jean, buso, tenis…)'),
        Row(
          children: [
            Expanded(child: texto(f.colorPrimario, 'Color principal')),
            const SizedBox(width: 12),
            Expanded(child: texto(f.colorSecundario, 'Color secundario')),
          ],
        ),
        texto(f.tela, 'Tela'),
        texto(f.estilo, 'Estilo'),
        opciones('Formalidad', f.formalidad, OpcionesPrenda.formalidades, (v) => f.formalidad = v),
        opciones('Estación', f.estacion, OpcionesPrenda.estaciones, (v) => f.estacion = v),
        texto(f.etiquetas, 'Etiquetas (separadas por coma)'),
        texto(f.precio, 'Precio en pesos (opcional, para el costo por uso)', teclado: TextInputType.number),
      ],
    );
  }
}
