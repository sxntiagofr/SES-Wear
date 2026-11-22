import 'package:material_ui/material_ui.dart';

import '../../../core/ia/servicio_ia.dart';
import '../../../core/theme/app_theme.dart';
import '../data/asistente_repositorio.dart';
import '../models/mensaje.dart';
import '../widgets/burbuja_mensaje.dart';

/// Pantalla del asistente de moda (RF-04).
///
/// El asistente conoce las prendas guardadas en el armario del usuario
/// (`users/{uid}/prendas` en Firestore) y guarda el historial en
/// `users/{uid}/conversaciones`.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.repositorio});

  /// Se puede inyectar otro repositorio en pruebas.
  final AsistenteRepositorio? repositorio;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _sugerencias = [
    '¿Qué me pongo hoy con lo que tengo?',
    'Arma un outfit para la U',
    '¿Qué combina con mi jean azul?',
  ];

  late final AsistenteRepositorio _repo;
  final _controlador = TextEditingController();
  final _scroll = ScrollController();
  final List<Mensaje> _mensajes = [];

  String? _conversacionId;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repositorio ?? AsistenteRepositorio();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _controlador.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    try {
      final id = await _repo.ultimaConversacionId();
      final mensajes = id == null ? <Mensaje>[] : await _repo.cargarMensajes(id);
      // Si el usuario ya empezó una conversación mientras cargaba el historial,
      // se conserva la suya en vez de reemplazarla por la anterior.
      if (!mounted || _mensajes.isNotEmpty || _conversacionId != null) return;
      setState(() {
        _conversacionId = id;
        _mensajes
          ..clear()
          ..addAll(mensajes);
      });
      _bajar();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el historial.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviar([String? textoSugerido]) async {
    final texto = (textoSugerido ?? _controlador.text).trim();
    if (texto.isEmpty || _enviando) return;

    _controlador.clear();
    setState(() {
      _error = null;
      _enviando = true;
      _mensajes.add(Mensaje(rol: RolMensaje.usuario, texto: texto, fecha: DateTime.now()));
    });
    _bajar();

    try {
      final respuesta = await _repo.enviar(
        historial: List.of(_mensajes),
        conversacionId: _conversacionId,
      );
      if (!mounted) return;
      setState(() {
        _conversacionId = respuesta.conversacionId ?? _conversacionId;
        _mensajes.add(Mensaje(
          rol: RolMensaje.asistente,
          texto: respuesta.texto,
          fecha: DateTime.now(),
        ));
      });
    } on ErrorIA catch (e) {
      _fallo(e.mensaje);
    } catch (_) {
      _fallo('No se pudo conectar con el asistente. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
      _bajar();
    }
  }

  // Si falla, se quita la pregunta para que el usuario pueda reintentar.
  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _error = mensaje;
      if (_mensajes.isNotEmpty && _mensajes.last.esDelUsuario) {
        _controlador.text = _mensajes.removeLast().texto;
      }
    });
  }

  void _nuevaConversacion() {
    setState(() {
      _conversacionId = null;
      _mensajes.clear();
      _error = null;
    });
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente de estilo'),
        actions: [
          IconButton(
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _enviando ? null : _nuevaConversacion,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _cuerpo()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_error!, style: TextStyle(color: AppTheme.error)),
              ),
            _campoDeTexto(),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _mensajes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mensajes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(
            'Pregúntame qué ponerte. Conozco las prendas de tu armario.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sugerencias)
                ActionChip(label: Text(s), onPressed: () => _enviar(s)),
            ],
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _mensajes.length + (_enviando ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _mensajes.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return BurbujaMensaje(mensaje: _mensajes[i]);
      },
    );
  }

  Widget _campoDeTexto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controlador,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta…',
                counterText: '',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Enviar',
            onPressed: _enviando ? null : () => _enviar(),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
