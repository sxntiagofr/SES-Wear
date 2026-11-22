import 'package:material_ui/material_ui.dart';

import '../../auth/data/auth_repositorio.dart';
import '../../auth/models/perfil_usuario.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../outfits/models/outfit.dart';

/// Editar datos personales y preferencias de estilo (las usan el asistente y
/// el generador de outfits).
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key, required this.perfil, required this.repositorio});

  final PerfilUsuario perfil;
  final AuthRepositorio repositorio;

  static const estilos = ['clásico', 'urbano', 'deportivo', 'elegante', 'bohemio', 'minimalista', 'casual'];
  static const colores = ['negro', 'blanco', 'gris', 'beige', 'azul', 'verde', 'rojo', 'rosado', 'morado', 'café'];

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.perfil.nombre);
  late final _apellido = TextEditingController(text: widget.perfil.apellido);
  late final _telefono = TextEditingController(text: widget.perfil.telefono);
  late final _ciudad = TextEditingController(text: widget.perfil.ciudad);
  late final _estilos = {...widget.perfil.preferencias.estilos};
  late final _colores = {...widget.perfil.preferencias.colores};
  late final _ocasiones = {...widget.perfil.preferencias.ocasiones};
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _telefono, _ciudad]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.repositorio.actualizarPerfil(
        widget.perfil.uid,
        nombre: _nombre.text,
        apellido: _apellido.text,
        telefono: _telefono.text,
        ciudad: _ciudad.text,
        preferencias: Preferencias(
          estilos: _estilos.toList(),
          colores: _colores.toList(),
          ocasiones: _ocasiones.toList(),
        ),
      );
      if (!mounted) return;
      mostrarMensaje(context, 'Tus datos se guardaron.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarMensaje(context, 'No se pudieron guardar tus datos. Revisa tu conexión.', error: true);
    }
  }

  Widget _chips(String titulo, List<String> opciones, Set<String> seleccion, {String Function(String)? etiqueta}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in opciones)
              FilterChip(
                label: Text(etiqueta?.call(o) ?? o[0].toUpperCase() + o.substring(1)),
                selected: seleccion.contains(o),
                onSelected: _guardando ? null : (v) => setState(() => v ? seleccion.add(o) : seleccion.remove(o)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final telefonoOpcional = widget.perfil.proveedor != 'password';
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CampoAuth(
                controller: _nombre,
                hint: 'Nombre',
                icono: Icons.person_outline,
                capitalizacion: TextCapitalization.words,
                validator: Validar.requerido('nombre'),
              ),
              const SizedBox(height: 12),
              CampoAuth(
                controller: _apellido,
                hint: 'Apellido',
                icono: Icons.how_to_reg_outlined,
                capitalizacion: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              CampoAuth(
                controller: _telefono,
                hint: 'Número de teléfono',
                icono: Icons.phone_outlined,
                teclado: TextInputType.phone,
                // Las cuentas de Google/Facebook no lo pidieron al registrarse.
                validator: (v) => telefonoOpcional && (v ?? '').trim().isEmpty ? null : Validar.telefono(v),
              ),
              const SizedBox(height: 12),
              CampoAuth(
                controller: _ciudad,
                hint: 'Ciudad (para recomendaciones según el clima)',
                icono: Icons.location_city_outlined,
                capitalizacion: TextCapitalization.words,
                accion: TextInputAction.done,
              ),
              _chips('Estilos que te gustan', EditarPerfilScreen.estilos, _estilos),
              _chips('Colores favoritos', EditarPerfilScreen.colores, _colores),
              _chips('Ocasiones frecuentes', OpcionesOutfit.ocasiones, _ocasiones,
                  etiqueta: OpcionesOutfit.etiquetaOcasion),
              const SizedBox(height: 24),
              BotonPrincipal(texto: 'Guardar', cargando: _guardando, onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}
