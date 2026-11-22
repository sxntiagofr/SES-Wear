import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_repositorio.dart';
import '../widgets/auth_widgets.dart';
import 'recuperar_contrasena_screen.dart';
import 'registro_screen.dart';

/// Ejecuta una acción de cuenta mostrando los errores como mensaje.
/// Devuelve `true` si terminó bien.
Future<bool> ejecutarAccionAuth(BuildContext context, Future<void> Function() accion) async {
  try {
    await accion();
    return true;
  } on InicioCancelado {
    return false;
  } on ErrorAuth catch (e) {
    if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
    return false;
  } catch (e) {
    if (context.mounted) {
      mostrarMensaje(context, 'Ocurrió un error inesperado. Inténtalo de nuevo.', error: true);
    }
    debugPrint('Error de autenticación: $e');
    return false;
  }
}

/// Pantalla «Iniciar sesión» (Figma: figma_inicio_sesion).
///
/// Al entrar, `AuthGate` detecta la sesión y abre la app; la sesión queda
/// guardada en el celular para las próximas veces.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repositorio});

  final AuthRepositorio? repositorio;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;

  AuthRepositorio get _repo => widget.repositorio ?? AuthRepositorio.instancia;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    await ejecutarAccionAuth(context, accion);
    if (mounted) setState(() => _cargando = false);
  }

  void _iniciarSesion() {
    if (!_formKey.currentState!.validate()) return;
    _ejecutar(() => _repo.iniciarSesion(email: _correo.text, contrasena: _contrasena.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LogoSesWear(alto: 280),
                      const SizedBox(height: 28),
                      CampoAuth(
                        controller: _correo,
                        hint: 'Correo electrónico',
                        icono: Icons.mail_outline,
                        teclado: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email, AutofillHints.username],
                        validator: Validar.correo,
                      ),
                      const SizedBox(height: 14),
                      CampoAuth(
                        controller: _contrasena,
                        hint: 'Contraseña',
                        icono: Icons.lock_outline,
                        esContrasena: true,
                        accion: TextInputAction.done,
                        autofill: const [AutofillHints.password],
                        validator: Validar.contrasenaLogin,
                        onSubmitted: (_) => _iniciarSesion(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RecuperarContrasenaScreen(
                                        correoInicial: _correo.text.trim(),
                                        repositorio: widget.repositorio,
                                      ),
                                    ),
                                  ),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      BotonPrincipal(
                        texto: 'Iniciar sesión',
                        cargando: _cargando,
                        onPressed: _iniciarSesion,
                      ),
                      const SizedBox(height: 28),
                      const SeparadorTexto('o continúa con'),
                      const SizedBox(height: 20),
                      BotonesSociales(
                        deshabilitados: _cargando,
                        onGoogle: () => _ejecutar(_repo.iniciarConGoogle),
                        onFacebook: () => _ejecutar(_repo.iniciarConFacebook),
                      ),
                      const SizedBox(height: 20),
                      EnlaceInferior(
                        pregunta: '¿No tienes cuenta?',
                        accion: 'Regístrate',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegistroScreen(repositorio: widget.repositorio),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: AppTheme.background,
    );
  }
}
