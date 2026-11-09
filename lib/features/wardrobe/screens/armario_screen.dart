import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../data/prendas_repositorio.dart';
import '../models/prenda.dart';
import '../widgets/tarjeta_prenda.dart';
import 'nueva_prenda_screen.dart';

/// Armario virtual (RF-02): prendas guardadas en Firestore y botón para
/// agregar una nueva tomando una foto (la IA identifica la prenda, RF-01).
class ArmarioScreen extends StatefulWidget {
  const ArmarioScreen({super.key, this.repositorio});

  final PrendasRepositorio? repositorio;

  @override
  State<ArmarioScreen> createState() => _ArmarioScreenState();
}

class _ArmarioScreenState extends State<ArmarioScreen> {
  late final PrendasRepositorio _repo;
  late final Stream<List<Prenda>> _prendas;

  @override
  void initState() {
    super.initState();
    _repo = widget.repositorio ?? PrendasRepositorio();
    _prendas = _repo.observar();
  }

  Future<void> _elegirOrigen() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;
    await agregarPrendaConFoto(context, origen: origen, repositorio: _repo);
  }

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
    if (eliminar == true) await _repo.eliminar(prenda);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi armario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _elegirOrigen,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Agregar prenda'),
      ),
      body: StreamBuilder<List<Prenda>>(
        stream: _prendas,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo cargar tu armario.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prendas = snapshot.data!;
          if (prendas.isEmpty) {
            return const Center(
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
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: prendas.length,
            itemBuilder: (context, i) => TarjetaPrenda(
              prenda: prendas[i],
              onLongPress: () => _confirmarEliminar(prendas[i]),
            ),
          );
        },
      ),
    );
  }
}
