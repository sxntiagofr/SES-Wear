import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Preferencia de tema del usuario (RNF-02: modo claro y oscuro).
enum ModoTema {
  sistema('Según el celular'),
  claro('Claro'),
  oscuro('Oscuro');

  const ModoTema(this.etiqueta);
  final String etiqueta;
}

/// Guarda el modo elegido en el celular y avisa cuando cambia.
///
/// Los colores de [AppTheme] leen `AppTheme.oscuro`; este controlador lo
/// actualiza antes de que la app se vuelva a dibujar.
class ControladorTema extends ValueNotifier<ModoTema> {
  ControladorTema([super.value = ModoTema.sistema]);

  static const _clave = 'modo_tema';

  /// Instancia de la app (la usa main.dart y la pantalla Perfil).
  static final instancia = ControladorTema();

  /// Lee el modo guardado. Si falla, se queda en "según el celular".
  Future<void> cargar() async {
    try {
      final guardado = (await SharedPreferences.getInstance()).getString(_clave);
      value = ModoTema.values.firstWhere((m) => m.name == guardado, orElse: () => ModoTema.sistema);
    } catch (_) {
      value = ModoTema.sistema;
    }
  }

  Future<void> cambiar(ModoTema modo) async {
    value = modo;
    try {
      await (await SharedPreferences.getInstance()).setString(_clave, modo.name);
    } catch (_) {
      // Si no se puede guardar, el cambio dura hasta cerrar la app.
    }
  }

  /// ¿Toca modo oscuro con este modo y el brillo del celular?
  static bool esOscuro(ModoTema modo, Brightness brilloSistema) => switch (modo) {
        ModoTema.claro => false,
        ModoTema.oscuro => true,
        ModoTema.sistema => brilloSistema == Brightness.dark,
      };
}

/// Aplica el tema a toda la app: escucha el modo elegido y el brillo del
/// celular, actualiza [AppTheme.oscuro] y redibuja todas las pantallas sin
/// perder la navegación ni lo que el usuario tenía abierto.
class AplicarTema extends StatefulWidget {
  const AplicarTema({super.key, required this.controlador, required this.builder});

  final ControladorTema controlador;
  final Widget Function(BuildContext context, ThemeData tema) builder;

  @override
  State<AplicarTema> createState() => _AplicarTemaState();
}

class _AplicarTemaState extends State<AplicarTema> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controlador.addListener(_actualizar);
    _calcular();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controlador.removeListener(_actualizar);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _actualizar();

  bool _calcular() {
    final brillo = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final oscuro = ControladorTema.esOscuro(widget.controlador.value, brillo);
    final cambio = oscuro != AppTheme.oscuro;
    AppTheme.oscuro = oscuro;
    return cambio;
  }

  void _actualizar() {
    if (!_calcular() || !mounted) return;
    setState(() {});
    // Las pantallas leen los colores de AppTheme directamente, así que se
    // marcan todas para redibujarse con el modo nuevo.
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, AppTheme.theme);
}
