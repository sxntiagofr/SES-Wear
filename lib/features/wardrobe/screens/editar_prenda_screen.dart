import 'package:material_ui/material_ui.dart';

import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';
import '../widgets/campos_prenda.dart';

/// Editar los datos de una prenda (RF-02). Devuelve `true` si se guardó.
class EditarPrendaScreen extends StatefulWidget {
  const EditarPrendaScreen({super.key, required this.prenda, required this.repositorio});

  final Prenda prenda;
  final PrendasRepositorio repositorio;

  @override
  State<EditarPrendaScreen> createState() => _EditarPrendaScreenState();
}

class _EditarPrendaScreenState extends State<EditarPrendaScreen> {
  final _form = GlobalKey<FormState>();
  final _formulario = FormularioPrenda();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _formulario.llenar(widget.prenda);
  }

  @override
  void dispose() {
    _formulario.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.repositorio.actualizar(_formulario.aPrenda(base: widget.prenda));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar los cambios. Inténtalo de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar prenda')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CamposPrenda(
                formulario: _formulario,
                habilitado: !_guardando,
                alCambiar: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.check),
                label: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
