import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/prendas_repositorio.dart';
import 'nueva_prenda_screen.dart';

/// Abre la cámara para agregar una prenda. Devuelve `true` si se guardó.
Future<bool> agregarPrenda(BuildContext context, {PrendasRepositorio? repositorio}) async {
  final guardada = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => CamaraScreen(repositorio: repositorio)),
  );
  return guardada == true;
}

/// Tipo de imagen de un archivo elegido o tomado.
String tipoDeImagen(XFile foto) {
  final tipo = foto.mimeType;
  if (tipo != null && tipo.startsWith('image/')) return tipo;
  final nombre = foto.name.toLowerCase();
  if (nombre.endsWith('.png')) return 'image/png';
  if (nombre.endsWith('.webp')) return 'image/webp';
  if (nombre.endsWith('.heic') || nombre.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Cámara del dispositivo con vista previa en vivo (RF-01): tomar la foto de
/// la prenda o elegirla de la galería. Funciona en Android, iOS y en el
/// navegador (usa la cámara del computador o del celular).
class CamaraScreen extends StatefulWidget {
  const CamaraScreen({super.key, this.repositorio, this.buscarCamaras, this.elegirDeGaleria});

  final PrendasRepositorio? repositorio;

  /// Para pruebas: reemplaza la búsqueda de cámaras del dispositivo.
  final Future<List<CameraDescription>> Function()? buscarCamaras;

  /// Para pruebas: reemplaza el selector de la galería.
  final Future<XFile?> Function()? elegirDeGaleria;

  @override
  State<CamaraScreen> createState() => _CamaraScreenState();
}

class _CamaraScreenState extends State<CamaraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _camaras = const [];
  CameraController? _controlador;
  int _indice = 0;
  String? _error;
  bool _iniciando = true;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlador?.dispose();
    super.dispose();
  }

  // La cámara se libera cuando la app pasa a segundo plano y se vuelve a abrir al regresar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final c = _controlador;
    if (c == null || !c.value.isInitialized) return;
    if (estado == AppLifecycleState.inactive) {
      _controlador = null;
      c.dispose();
    } else if (estado == AppLifecycleState.resumed && _camaras.isNotEmpty) {
      _abrir(_camaras[_indice]);
    }
  }

  Future<void> _iniciar() async {
    setState(() {
      _iniciando = true;
      _error = null;
    });
    try {
      final camaras = await (widget.buscarCamaras ?? availableCameras)();
      if (!mounted) return;
      if (camaras.isEmpty) {
        setState(() {
          _iniciando = false;
          _error = 'No se encontró ninguna cámara en este dispositivo. Puedes elegir una foto de la galería.';
        });
        return;
      }
      _camaras = camaras;
      final trasera = camaras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _indice = trasera >= 0 ? trasera : 0;
      await _abrir(camaras[_indice]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _iniciando = false;
          _error = _mensajeDeError(e);
        });
      }
    }
  }

  Future<void> _abrir(CameraDescription camara) async {
    final anterior = _controlador;
    _controlador = null;
    await anterior?.dispose();
    final nuevo = CameraController(camara, ResolutionPreset.high, enableAudio: false);
    try {
      await nuevo.initialize();
      if (!mounted) {
        await nuevo.dispose();
        return;
      }
      setState(() {
        _controlador = nuevo;
        _iniciando = false;
        _error = null;
      });
    } catch (e) {
      await nuevo.dispose();
      if (mounted) {
        setState(() {
          _iniciando = false;
          _error = _mensajeDeError(e);
        });
      }
    }
  }

  static String _mensajeDeError(Object e) {
    if (e is CameraException) {
      final codigo = e.code.toLowerCase();
      if (codigo.contains('denied') || codigo.contains('permission')) {
        return 'Permite el acceso a la cámara en los ajustes del navegador o del celular y vuelve a intentarlo.';
      }
      if (codigo.contains('notfound')) return 'No se encontró ninguna cámara en este dispositivo.';
      if (codigo.contains('notreadable') || codigo.contains('inuse')) {
        return 'La cámara está siendo usada por otra aplicación. Ciérrala y vuelve a intentarlo.';
      }
    }
    return 'No se pudo abrir la cámara. Puedes elegir una foto de la galería.';
  }

  Future<void> _cambiarCamara() async {
    if (_camaras.length < 2 || _ocupado) return;
    setState(() => _ocupado = true);
    _indice = (_indice + 1) % _camaras.length;
    await _abrir(_camaras[_indice]);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _tomarFoto() async {
    final c = _controlador;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      final foto = await c.takePicture();
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      await _continuar(bytes, tipoDeImagen(foto));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo tomar la foto. Inténtalo de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _galeria() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      // Se reduce a ~1024 px: suficiente para la IA y más rápido de subir (RNF-01).
      final foto = await (widget.elegirDeGaleria ??
          () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85))();
      if (foto == null || !mounted) return;
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      await _continuar(bytes, tipoDeImagen(foto));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo abrir la galería. Revisa los permisos de la app.')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Abre el formulario de la prenda; si se guarda, cierra la cámara.
  Future<void> _continuar(Uint8List foto, String tipo) async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NuevaPrendaScreen(foto: foto, tipoImagen: tipo, repositorio: widget.repositorio)),
    );
    if (guardada == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controlador;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cerrar',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Agregar prenda',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cambiar de cámara',
                    color: Colors.white,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    onPressed: _camaras.length > 1 && !_ocupado ? _cambiarCamara : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _iniciando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _error != null
                        ? _vistaError()
                        : c != null && c.value.isInitialized
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                // CameraPreview ajusta la proporción según la orientación.
                                child: CameraPreview(c),
                              )
                            : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Pon la prenda completa sobre un fondo liso y con buena luz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BotonRedondo(
                    etiqueta: 'Galería',
                    icono: Icons.photo_library_outlined,
                    onPressed: _ocupado ? null : _galeria,
                  ),
                  Semantics(
                    button: true,
                    label: 'Tomar foto',
                    child: GestureDetector(
                      onTap: c != null && _error == null ? _tomarFoto : null,
                      child: Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c != null && _error == null && !_ocupado ? Colors.white : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vistaError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.4)),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _ocupado ? null : _galeria,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Elegir de la galería'),
          ),
          TextButton(
            onPressed: _iniciar,
            child: const Text('Reintentar con la cámara', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.etiqueta, required this.icono, required this.onPressed});

  final String etiqueta;
  final IconData icono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: etiqueta,
          iconSize: 26,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            fixedSize: const Size(56, 56),
          ),
          onPressed: onPressed,
          icon: Icon(icono),
        ),
        const SizedBox(height: 4),
        Text(etiqueta, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
