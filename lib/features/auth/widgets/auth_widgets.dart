import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Logo de SES Wear con el eslogan, en tarjeta redondeada (como en Figma).
class LogoSesWear extends StatelessWidget {
  const LogoSesWear({super.key, this.alto = 300});

  final double alto;

  @override
  Widget build(BuildContext context) {
    // El logo se muestra completo (con el eslogan); a los lados se rellena con
    // un degradado del mismo morado del fondo de la imagen.
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: alto,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C0C33), Color(0xFF0F0829)],
          ),
        ),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'SES Wear. Tu estilo, más inteligente',
        ),
      ),
    );
  }
}

/// Campo de texto de las pantallas de cuenta, con ícono y, si es contraseña,
/// botón para mostrarla u ocultarla.
class CampoAuth extends StatefulWidget {
  const CampoAuth({
    super.key,
    required this.controller,
    required this.hint,
    required this.icono,
    this.esContrasena = false,
    this.teclado,
    this.accion = TextInputAction.next,
    this.autofill,
    this.validator,
    this.onSubmitted,
    this.capitalizacion = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icono;
  final bool esContrasena;
  final TextInputType? teclado;
  final TextInputAction accion;
  final Iterable<String>? autofill;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization capitalizacion;

  @override
  State<CampoAuth> createState() => _CampoAuthState();
}

class _CampoAuthState extends State<CampoAuth> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.esContrasena && _oculta,
      keyboardType: widget.teclado,
      textInputAction: widget.accion,
      autofillHints: widget.autofill,
      textCapitalization: widget.capitalizacion,
      autocorrect: !widget.esContrasena,
      enableSuggestions: !widget.esContrasena,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(widget.icono, size: 22),
        suffixIcon: widget.esContrasena
            ? IconButton(
                tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_oculta ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _oculta = !_oculta),
              )
            : null,
      ),
    );
  }
}

/// Botón principal morado; muestra un indicador mientras carga.
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radioBoton),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(texto),
      ),
    );
  }
}

/// Línea con texto en el medio: «o continúa con».
class SeparadorTexto extends StatelessWidget {
  const SeparadorTexto(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(texto, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Botones redondos de Google y Facebook.
class BotonesSociales extends StatelessWidget {
  const BotonesSociales({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
    this.deshabilitados = false,
  });

  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final bool deshabilitados;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BotonCircular(
          etiqueta: 'Continuar con Google',
          onPressed: deshabilitados ? null : onGoogle,
          child: const Text(
            'G',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 24),
        _BotonCircular(
          etiqueta: 'Continuar con Facebook',
          onPressed: deshabilitados ? null : onFacebook,
          child: const Icon(Icons.facebook, color: Colors.white, size: 28),
        ),
      ],
    );
  }
}

class _BotonCircular extends StatelessWidget {
  const _BotonCircular({required this.etiqueta, required this.onPressed, required this.child});

  final String etiqueta;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: etiqueta,
      child: Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: AppTheme.surface,
          shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(width: 48, height: 48, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// «¿No tienes cuenta? Regístrate» y similares.
class EnlaceInferior extends StatelessWidget {
  const EnlaceInferior({super.key, required this.pregunta, required this.accion, required this.onTap});

  final String pregunta;
  final String accion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap y no Row: en pantallas angostas o con letra grande pasa a dos líneas.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(pregunta, style: const TextStyle(color: AppTheme.textSecondary)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
          child: Text(accion, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Validaciones de los formularios de cuenta.
class Validar {
  Validar._();

  static final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? correo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Escribe tu correo electrónico.';
    if (!_correo.hasMatch(v)) return 'El correo no tiene un formato válido.';
    return null;
  }

  static String? contrasenaLogin(String? valor) =>
      (valor ?? '').isEmpty ? 'Escribe tu contraseña.' : null;

  static String? contrasenaNueva(String? valor) {
    final v = valor ?? '';
    if (v.length < 8) return 'Usa al menos 8 caracteres.';
    if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Combina letras y números.';
    }
    return null;
  }

  static String? Function(String?) requerido(String campo) => (valor) =>
      (valor?.trim().isEmpty ?? true) ? 'Escribe tu $campo.' : null;

  /// Teléfono colombiano u otro: entre 7 y 15 dígitos, con + opcional.
  static String? telefono(String? valor) {
    final digitos = (valor ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (digitos.isEmpty) return 'Escribe tu número de teléfono.';
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digitos)) return 'Número de teléfono no válido.';
    return null;
  }
}

/// Muestra un mensaje corto abajo de la pantalla.
void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? const Color(0xFF3A1626) : AppTheme.surface,
      ),
    );
}

/// Texto de la autorización de tratamiento de datos (Ley 1581 de 2012).
Future<void> mostrarPoliticaDatos(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tratamiento de datos personales'),
      content: const SingleChildScrollView(
        child: Text(
          'De acuerdo con la Ley 1581 de 2012 y el Decreto 1377 de 2013, autorizo a SES Wear '
          '(proyecto académico de la Universidad Militar Nueva Granada) para recolectar, '
          'almacenar y usar mis datos personales —nombre, apellido, teléfono, correo, ciudad, '
          'preferencias y las fotos de mis prendas— con el único fin de prestar el servicio de '
          'la aplicación: armario digital, recomendaciones de outfits y asistente de moda.\n\n'
          'Mis datos se guardan cifrados en Google Firebase, solo yo puedo verlos y no se venden '
          'ni se comparten con terceros. Las fotos se envían a servicios de inteligencia '
          'artificial únicamente para analizarlas.\n\n'
          'Puedo conocer, actualizar, rectificar y suprimir mis datos en cualquier momento desde '
          'Perfil, o eliminar mi cuenta y toda su información.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    ),
  );
}
